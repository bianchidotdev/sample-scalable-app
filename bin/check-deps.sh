#!/usr/bin/env bash
set -e

echo "Starting dependency checking"

DEPS=(
  aws
  eksctl
  helm
  kubectl
  terraform
)

echo "Checking required deps"

EXIT_CODE=0
for dependency in ${DEPS[@]}; do
  if test ! $(which $dependency); then
    echo "Missing dependency ${dependency}"
    EXIT_CODE=1
  else echo "$dependency already installed"
  fi
done

exit $EXIT_CODE
