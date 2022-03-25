function wait_start() {
  for ip in "$@"; do
    success_attempts=0
    # ~15 minutes to start
    for i in {1..60}; do
      if [[ ${i} == 60 ]]; then
        echo "timeout waiting for the ${ip} to start, aborting..."
        return 1
      fi

      # shellcheck disable=SC2086
      if ssh ${SSH_OPTS} -o ConnectTimeout=1 -o BatchMode=yes root@${ip} true; then
        ((success_attempts++))
      else
        success_attempts=0
      fi

      if [[ ${success_attempts} == 3 ]]; then
        break
      fi

      sleep 15
    done
  done
  return 0
}
