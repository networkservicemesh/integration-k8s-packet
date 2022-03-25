function wait_pids() {
  pids="$1"
  message="$2"
  for pid in ${pids}; do
    echo "waiting for PID ${pid}"
    # shellcheck disable=SC2086
    wait ${pid}
    code=$?
    if test $code -ne 0; then
      echo "${message}: process exited with code $code, aborting..."
      return 1
    fi
  done
  return 0
}
