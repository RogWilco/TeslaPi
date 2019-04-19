#!/usr/bin/env bash

file::append_once() {
  local target="$1"
  local append="$2"

  # If file exists, and line exists, return.
  if [ -f "$target" ]; then
    if grep -Fxq "${append}" "${target}"; then
      return 0
    fi
  fi

  # Append Line
  printf "\n%s\n" "${append}" >> "${target}"
}
