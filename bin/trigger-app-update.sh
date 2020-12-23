#!/usr/bin/env bash
set -e

kubectl rollout restart deploy $1