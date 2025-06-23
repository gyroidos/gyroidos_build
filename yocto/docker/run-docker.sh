#!/bin/bash
# $1: workspace directory

show_help() {
  echo "Usage:"
  echo "  -w --workspace: folder in which yocto will be initialized"
  echo "  -s --ssh: ssh-agent socket"
  echo "  -c --cache: cache folder (downloads, sstate-cache)"
  echo "  -p --pki: pki folder"
  echo "  -d --pcscd: map pcscd socket from host to container"
}


main() {
	ARGUMENTS=""

    while :; do
        case $1 in
            -h|-\?|--help)
                show_help
                exit
                ;;
            -w|--workspace)
                if [ "$2" ]; then
                    ARGUMENTS="-v $2:/opt/ws-yocto/ "
                    shift
                else
                    echo 'Error: "--workspace" requires a non-empty option argument.' >&2
                    exit 1
                fi
                ;;
            -s|--ssh)
                if [ "$2" ]; then
                    ARGUMENTS+="-v $2:/tmp/sshagent --env=SSH_AUTH_SOCK=/tmp/sshagent "
                    shift
                else
                    echo 'Error: "--ssh" requires a non-empty option argument.'
                    exit 1
                fi
                ;;
            -c|--cache)
                if [ "$2" ]; then
                    ARGUMENTS+="-v $2:/opt/cache/ "
                    shift
                fi
            ;;
            -p|--pki)
                if [ "$2" ]; then
                    ARGUMENTS+="-v $2:/opt/pki/ "
                    shift
                fi
            ;;
            -d|--pcscd)
                ARGUMENTS+="--mount type=bind,source=/var/run/pcscd,target=/var/run/pcscd "
            ;;
            --)
                shift
                break
                ;;
            -?*)
                printf 'WARN: Unknown option (ignored): %s\n' "$1" >&2
                ;;
            *)
                break
        esac
        shift
    done

    docker run \
        -it \
        ${ARGUMENTS} \
        --mount type=tmpfs,dst=/opt/tmpfs,tmpfs-size=10485760 \
        -u "$(id -u $USER)" \
        -v /home/$(id -un)/.ssh/known_hosts:/home/builder/.ssh/known_hosts \
        --env=LANG=en_US.UTF-8 \
        --env=LANGUAGE=en_US.UTF-8 \
        gyroidos-builder \
        bash
}

main "$@"
