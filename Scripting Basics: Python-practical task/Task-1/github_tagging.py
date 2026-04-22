# github_tagging.py
import requests
import sys
import argparse

GITHUB_API = "https://api.github.com"

def get_latest_tag(repo, token):
    url = f"{GITHUB_API}/repos/{repo}/tags"
    headers = {"Authorization": f"token {token}"}
    response = requests.get(url, headers=headers)
    tags = response.json()
    return tags[0]["name"] if tags else None

def create_tag(repo, token, tag_name, commit_sha):
    url = f"{GITHUB_API}/repos/{repo}/git/refs"
    headers = {"Authorization": f"token {token}"}
    data = {
        "ref": f"refs/tags/{tag_name}",
        "sha": commit_sha
    }
    response = requests.post(url, json=data, headers=headers)
    print(f"Created tag: {tag_name}")

def get_latest_commit(repo, token):
    url = f"{GITHUB_API}/repos/{repo}/commits/main"
    headers = {"Authorization": f"token {token}"}
    response = requests.get(url, headers=headers)
    return response.json()["sha"]

def increment_version(version):
    x, y, z = map(int, version.split("."))
    return f"{x}.{y+1}.{z}"

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--repo", required=True)
    parser.add_argument("--token", required=True)
    parser.add_argument("--create-release", action="store_true")
    args = parser.parse_args()

    latest = get_latest_tag(args.repo, args.token)
    version = "1.0.0" if not latest else latest.replace("rc/", "")

    new_version = increment_version(version)
    commit_sha = get_latest_commit(args.repo, args.token)

    # RC Tag
    rc_tag = f"rc/{new_version}"
    create_tag(args.repo, args.token, rc_tag, commit_sha)

    if args.create_release:
        create_tag(args.repo, args.token, new_version, commit_sha)

if __name__ == "__main__":
    main()