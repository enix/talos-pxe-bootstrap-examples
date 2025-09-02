#!/usr/bin/env python

import argparse
import os
import pathlib
import json
import functools

import yaml


@functools.cache
def get_defaults(directory, root):
    """Compute the defaults from the provided directory and parents."""
    try:
        with open(directory.joinpath("_defaults.yaml")) as fyaml:
            yml_data = yaml.safe_load(fyaml)
    except OSError:
        yml_data = {}
    if directory != root:  # Stop recursion when reaching root directory
        return get_defaults(directory.parent, root) | yml_data
    else:
        return yml_data


def walk_files(root):
    for dirpath, dirnames, filenames in root.walk():
        for fn in filenames:
            if not fn.startswith("_"):
                yield dirpath.joinpath(fn)


def main(args):
    data = []
    for fullname in walk_files(args.directory):
        filename = (
            str(fullname.relative_to(args.directory).parent) + "/" + fullname.stem
        )
        if args.filter is not None and not filename.startswith(args.filter):
            continue
        with open(fullname) as fyaml:
            yml_data = yaml.safe_load(fyaml)
        yml_data = get_defaults(fullname.parent, args.directory) | yml_data
        yml_data["hostname"] = fullname.stem
        yml_data["filename"] = filename
        data.append(yml_data)

    print(json.dumps(data))


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("directory", type=pathlib.Path)
    parser.add_argument("-f", "--filter")
    args = parser.parse_args()
    main(args)
