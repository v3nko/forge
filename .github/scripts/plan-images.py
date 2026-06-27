#!/usr/bin/env python3
import argparse
import json
from pathlib import Path


def expand_requested(requested, images):
    if requested == "all":
        return list(images.keys())
    return [image.strip() for image in requested.split(",") if image.strip()]

def sort_selected(selected, images):
    selected_set = set(selected)
    ordered = []
    visiting = set()
    visited = set()

    def visit(image_name):
        if image_name in visited:
            return
        if image_name in visiting:
            raise SystemExit(f"Dependency cycle detected at image: {image_name}")
        visiting.add(image_name)
        for dependency in images[image_name].get("dependencies", []):
            if dependency in selected_set:
                visit(dependency)
        visiting.remove(image_name)
        visited.add(image_name)
        ordered.append(image_name)

    for image_name in selected:
        visit(image_name)
    return ordered


def build_args(image, images, selected, lane, namespace, prefer_local_dependencies):
    args = {}
    for key, value in image.get("buildArgs", {}).items():
        if value in images:
            if prefer_local_dependencies and value in selected:
                args[key] = f"forge/{value}:ci"
            else:
                args[key] = f"{namespace}/{value}:{lane}"
        else:
            args[key] = value
    return args


def tags_for(image_name, lane, version, namespace):
    if lane == "edge":
        return [f"{namespace}/{image_name}:edge"]

    if lane != "stable":
        raise ValueError(f"Unsupported lane: {lane}")
    if not version.startswith("v"):
        raise ValueError("Stable version must use a Git tag like v1.2.3")

    plain_version = version[1:]
    return [
        f"{namespace}/{image_name}:stable",
        f"{namespace}/{image_name}:edge",
        f"{namespace}/{image_name}:{plain_version}",
    ]


parser = argparse.ArgumentParser()
parser.add_argument("--manifest", default="images/manifest.json")
parser.add_argument("--images", required=True)
parser.add_argument("--lane", required=True)
parser.add_argument("--version", default="")
parser.add_argument("--namespace", required=True)
args = parser.parse_args()

manifest = json.loads(Path(args.manifest).read_text())
images = manifest["images"]
selected = expand_requested(args.images, images)

unknown = [image for image in selected if image not in images]
if unknown:
    raise SystemExit(f"Unknown image(s): {', '.join(unknown)}")

selected = sort_selected(selected, images)

matrix = []
for image_name in selected:
    image = images[image_name]
    image_build_args = build_args(image, images, selected, args.lane, args.namespace, True)
    image_deploy_build_args = build_args(image, images, selected, args.lane, args.namespace, False)
    matrix.append({
        "name": image_name,
        "dockerfile": image["dockerfile"],
        "build_args": image_build_args,
        "build_args_lines": "\n".join(f"{key}={value}" for key, value in image_build_args.items()),
        "deploy_build_args": image_deploy_build_args,
        "deploy_build_args_lines": "\n".join(f"{key}={value}" for key, value in image_deploy_build_args.items()),
        "tags": tags_for(image_name, args.lane, args.version, args.namespace),
        "tags_lines": "\n".join(tags_for(image_name, args.lane, args.version, args.namespace)),
    })

print(json.dumps({"include": matrix}, separators=(",", ":")))
