#!/usr/bin/env python3
import argparse
import json
from pathlib import Path


def expand_requested(requested, images):
    if requested == "all":
        return list(images.keys())
    return [image.strip() for image in requested.split(",") if image.strip()]


def image_for_path(path, images):
    for image_name in images:
        prefix = f"images/{image_name}/"
        if path.startswith(prefix):
            return image_name
    return None


def reverse_dependencies(images):
    dependents = {image_name: set() for image_name in images}
    for image_name, image in images.items():
        for dependency in image.get("dependencies", []):
            if dependency in dependents:
                dependents[dependency].add(image_name)
    return dependents


def impacted_images(changed_paths, images):
    changed_images = {
        image_name
        for image_name in (image_for_path(path, images) for path in changed_paths)
        if image_name
    }
    dependents = reverse_dependencies(images)
    impacted = set()

    def add_with_dependents(image_name):
        if image_name in impacted:
            return
        impacted.add(image_name)
        for dependent in dependents.get(image_name, set()):
            add_with_dependents(dependent)

    for image_name in changed_images:
        add_with_dependents(image_name)
    return sort_selected(list(impacted), images)


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
        f"{namespace}/{image_name}:latest",
        f"{namespace}/{image_name}:edge",
        f"{namespace}/{image_name}:{plain_version}",
    ]


parser = argparse.ArgumentParser()
parser.add_argument("--manifest", default="images/manifest.json")
parser.add_argument("--images")
parser.add_argument("--lane", required=True)
parser.add_argument("--version", default="")
parser.add_argument("--namespace", default="")
parser.add_argument("--changed-files")
parser.add_argument("--output", choices=["matrix", "images"], default="matrix")
args = parser.parse_args()

manifest = json.loads(Path(args.manifest).read_text())
images = manifest["images"]

if args.changed_files:
    changed_paths = [
        path.strip()
        for path in Path(args.changed_files).read_text().splitlines()
        if path.strip()
    ]
    selected = impacted_images(changed_paths, images)
else:
    if not args.images:
        raise SystemExit("--images is required unless --changed-files is provided")
    selected = expand_requested(args.images, images)

unknown = [image for image in selected if image not in images]
if unknown:
    raise SystemExit(f"Unknown image(s): {', '.join(unknown)}")

selected = sort_selected(selected, images)

if args.output == "images":
    print(",".join(selected))
    raise SystemExit(0)

if not args.namespace:
    raise SystemExit("--namespace is required for matrix output")

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
