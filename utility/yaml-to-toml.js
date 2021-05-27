#!/usr/bin/env node
"use strict";

const argparse = require("argparse");
const fs = require("fs");
const toml = require("@iarna/toml");
const yaml = require("js-yaml");

var parser = new argparse.ArgumentParser({
	description: 'Convert YAML to TOML.'
});
parser.addArgument('input', {
	nargs: '?',
	defaultValue: process.stdin.fd,
	metavar: 'INPUT',
	help: 'YAML data file (if omitted, YAML data is read from the standard input).'
});
parser.addArgument(['-o', '--output'], {
	defaultValue: process.stdout.fd,
	help: 'TOML data file (if omitted, TOML data is written to the standard output).'
});

var args = parser.parseArgs();

const yamlString = fs.readFileSync(args.input, "utf-8");
const yamlDoc = yaml.safeLoad(yamlString);
const tomlString = toml.stringify(yamlDoc);
fs.writeFileSync(args.output, tomlString);

// vim:set cino=(s:
