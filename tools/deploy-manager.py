import argparse
import yaml
from dotenv import load_dotenv
import os
import requests
import subprocess
import json
import time
from datetime import datetime, timezone


def parse_arguments():
    """Parse command-line arguments and return the populated namespace."""
    parser = argparse.ArgumentParser()
    subparsers = parser.add_subparsers(dest="command")

    list_versions_parser = subparsers.add_parser("list-versions")
    current_version_parser = subparsers.add_parser("current-version")
    deploy_parser = subparsers.add_parser("deploy")
    status_parser = subparsers.add_parser("status")
    rollback_parser = subparsers.add_parser("rollback")
    deploy_parser.add_argument("version")

    args = parser.parse_args()
    return args


def load_history(config):
    """Load deployment history from JSON file. Returns empty list if file does not exist."""
    if os.path.exists(config["history_file_path"]):
        with open(config["history_file_path"]) as f:
            deploy_history = json.load(f)
            return deploy_history
    else:
        with open(config["history_file_path"], "w") as f:
            json.dump([], f, indent=2)
        return []


def save_history(deploy_history, config):
    """Write current deployment history to JSON file."""
    path = config["history_file_path"]
    tmp = path + ".tmp"
    with open(tmp, "w") as f:
        json.dump(deploy_history, f, indent=2)
    os.replace(tmp, path)


def get_ec2_ip():
    """Retrieve EC2 public IP from Terraform output."""
    command = "cd ../terraform && terraform output"
    result = subprocess.run(command, shell=True, capture_output=True, text=True)
    outputs = result.stdout.split("\n")
    for output in outputs:
        if output.startswith("web_public_ip"):
            return output.split(" ")[2].strip().replace('"', "")


def load_config():
    """Load configuration from .env and config.yml. Returns unified config dict."""
    load_dotenv()
    token = os.getenv("GITHUB_TOKEN")
    if token is None:
        raise RuntimeError("GITHUB_TOKEN is not set in environment")
    
    config = {
        "github_token": token,
        "ec2ip": get_ec2_ip()
    }

    with open("config.yml", "r") as file:
        data = yaml.safe_load(file)
        for key, value in data.items():
            if isinstance(value, str) and value.startswith("~"):
                config[key] = os.path.expanduser(value)
            else:
                config[key] = value

    return config


def filter_releases(tags):
    return [t for t in tags if len(t.split(".")) == 3]


def fetch_versions(config):
    """Fetch available image tags from GHCR. Returns list of tag strings."""
    user = config["github_username"]
    token = config["github_token"]
    url = "https://ghcr.io/token?service=ghcr.io&scope=repository:"+ user +"/task-manager-backend:pull"
    url2 = "https://ghcr.io/v2/"+ user +"/task-manager-backend/tags/list"

    response = requests.get(url, auth=(user, token))
    response.raise_for_status()
    token = response.json()["token"]

    headers ={
        "Authorization": "Bearer " + token
    }

    response = requests.get(url2, headers=headers)
    response.raise_for_status()
    tag_list = response.json()["tags"]
    return tag_list


def cmd_list_versions(config):
    """Print all available semantic version releases from GHCR."""
    tag_list = fetch_versions(config)
    result_tag_list = filter_releases(tag_list)
    
    print("Available releases:")
    for tag in result_tag_list:
            print("v"+tag, end="\n")


def ssh_run(command, config):
    """Run a shell command on EC2 via SSH. Returns stdout on success."""
    result = subprocess.run(
        ["ssh", f"{config['ssh_user']}@{config['ec2ip']}", command],  
        capture_output=True, 
        text=True
    )

    if result.returncode == 0:
        return result.stdout
    else:
        raise RuntimeError(result.stderr)


def cmd_current_version(config):
    """Return the image tag currently running on EC2."""
    output = ssh_run(f"docker inspect {config['container_name']}", config)
    data = json.loads(output)
    return data[0]["Config"]["Image"].split(":")[-1]


def check_app_health(config, attempts=10, interval=3):
    """Check the app health via GET on /api/health endpoint"""
    url = f"http://{config['ec2ip']}/api/health"
    for i in range(attempts):
        try:
            response = requests.get(url, timeout=5)
            if response.status_code == 200 and response.json()["status"] == "healthy":
                return response.json()
        except (requests.ConnectionError, requests.Timeout, ValueError):
            pass
        time.sleep(interval)
    return None


def trigger_workflow(version, config):
    """Trigger the CD workflow via GitHub API. Returns run metadata dict."""
    url = f"https://api.github.com/repos/{config['github_username']}/{config['repo_name']}/actions/workflows/{config['workflow_file']}/dispatches"

    headers = {
        "Accept": "application/vnd.github+json",
        "Authorization": "Bearer " + config["github_token"],
        "X-GitHub-Api-Version": "2026-03-10"
    }

    data = {
        "ref": config['git_branch'],
        "inputs": {
            "sha": version
        }
    }

    response = requests.post(url, headers=headers, json=data)
    response.raise_for_status()

    return response.json()


def cmd_deploy(version, config, deploy_history):
    """Validate version, trigger deployment, watch progress, and record result."""
    if version in filter_releases(fetch_versions(config)):
        workflow_run_response = trigger_workflow(version, config)
        print(f"Deployment started: {workflow_run_response['html_url']}")

        entry = {
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "version": version,
            "success": None,
            "app_healthy": None,
            "run_id": workflow_run_response["workflow_run_id"],
            "run_url": workflow_run_response["run_url"],
            "html_url": workflow_run_response["html_url"]
        }
        deploy_history.append(entry)

        status, conclusion = watch_deploy(workflow_run_response, config)
        deploy_history[-1]["success"] = (conclusion == "success")

        if conclusion == "success":
            health_dict = check_app_health(config)
            deploy_history[-1]["app_healthy"] = health_dict is not None
            if health_dict:
                print("The app is healthy")
            else:
                print("The app isn't healthy. The rollback is needed.")
        else:
            deploy_history[-1]["app_healthy"] = False

        save_history(deploy_history, config)

    else:
        print("Wrong version given")
        exit(1)


def watch_deploy(workflow_run_response, config, max_wait=900):
    """Poll GitHub Actions run until completion. Displays spinner. Returns (status, conclusion)."""
    frames = ["|", "/", "-", "\\"]
    spinner_i = 0
    last_request_time = 0
    interval = 5
    start = time.time()

    while True:
        if time.time() - start > max_wait:
            raise TimeoutError(f"Deploy didn't complete in {max_wait}s")
        
        now = time.time()

        if now - last_request_time >= interval:
            response = requests.get(workflow_run_response["run_url"], headers={"Authorization": f"Bearer {config['github_token']}"})
            response.raise_for_status()
            data = response.json()

            if data["status"] == "completed":
                break

            last_request_time = now

        print(f"{frames[spinner_i % len(frames)]} waiting for the deployment to finish", end="\r")
        spinner_i += 1
        time.sleep(0.2)

    print(f"\rDeploy done. Status {data['status']}. Conclusion {data['conclusion']}")
    return data["status"], data["conclusion"]


def status(config):
    """Print current production version and list of available releases."""
    print("Current deployed version:")
    print(f"Production version: v{cmd_current_version(config)}")
    cmd_list_versions(config)


def cmd_rollback(config, deploy_history):
    """Deploy the last successful version that differs from current production."""
    successfull_entries = [x for x in deploy_history if x["success"] == True and x["app_healthy"] == True]
    current_version = cmd_current_version(config)
    if len(successfull_entries) == 0:
        print("There isn't any successfull deploy yet")
        exit(1)
    if successfull_entries[-1]["version"] != current_version:
        cmd_deploy(successfull_entries[-1]["version"], config, deploy_history)
    else:
        print("Already on last working version")
        exit(1)


def main():
    """Entry point. Parses arguments, loads config and history, routes to command."""
    args = parse_arguments()
    config = load_config()
    deploy_history = load_history(config)

    if args.command == "list-versions":
        cmd_list_versions(config)
    elif args.command == "current-version":
        print(f"Production version: v{cmd_current_version(config)}")
    elif args.command == "deploy":
        cmd_deploy(args.version, config, deploy_history)
    elif args.command == "status":
        status(config)
    elif args.command == "rollback":
        cmd_rollback(config, deploy_history)


main()