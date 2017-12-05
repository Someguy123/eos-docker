#!/bin/bash
#
# EOS node manager
# Released under GNU AGPL by Someguy123
#

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
DOCKER_DIR="$DIR/dkr"
# FULL_DOCKER_DIR="$DIR/dkr_fullnode"
DATADIR="$DIR/data"
MOUNTDIR="/opt/eos/bin/data-dir"
DOCKER_NAME="seed"

BOLD="$(tput bold)"
RED="$(tput setaf 1)"
GREEN="$(tput setaf 2)"
YELLOW="$(tput setaf 3)"
BLUE="$(tput setaf 4)"
MAGENTA="$(tput setaf 5)"
CYAN="$(tput setaf 6)"
WHITE="$(tput setaf 7)"
RESET="$(tput sgr0)"

# default. override in .env
PORTS="8888,9876"

if [[ -f .env ]]; then
    source .env
fi

#if [[ ! -f data/witness_node_data_dir/config.ini ]]; then
#    echo "config.ini not found. copying example (seed)";
#    cp data/witness_node_data_dir/config.ini.example data/witness_node_data_dir/config.ini
#fi

IFS=","
DPORTS=()
for i in $PORTS; do
    if [[ $i != "" ]]; then
            DPORTS+=("-p0.0.0.0:$i:$i")
    fi
done

help() {
    echo "Usage: $0 COMMAND [DATA]"
    echo
    echo "Commands: "
    echo "    start - starts eos container"
    echo "    dlblocks - download and decompress the blockchain to speed up your first start"
    echo "    replay - starts eos container (in replay mode)"
    echo "    shm_size - resizes /dev/shm to size given, e.g. ./run.sh shm_size 10G "
    echo "    stop - stops eos container"
    echo "    status - show status of eos container"
    echo "    restart - restarts eos container"
    echo "    install_docker - install docker"
    echo "    install - pulls latest docker image from server (no compiling)"
    echo "    install_full - pulls latest (FULL NODE FOR RPC) docker image from server (no compiling)"
    echo "    rebuild - builds eos container (from docker file), and then restarts it"
    echo "    build - only builds eos container (from docker file)"
    echo "    logs - show all logs inc. docker logs, and eos logs"
    echo "    wallet - open cli_wallet in the container"
    echo "    remote_wallet - open cli_wallet in the container connecting to a remote seed"
    echo "    enter - enter a bash session in the container"
    echo
    exit
}


#build() {
#    echo $GREEN"Building docker container"$RESET
#    cd $DOCKER_DIR
#    docker build -t eos .
#}


#dlblocks() {
#    if [[ ! -d "$DATADIR/blockchain" ]]; then
#        mkdir "$DATADIR/blockchain"
#    fi
#    echo "Removing old block log"
#    sudo rm -f $DATADIR/witness_node_data_dir/blockchain/block_log
#    sudo rm -f $DATADIR/witness_node_data_dir/blockchain/block_log.index
#    echo "Download @gtg's block logs..."
#    if [[ ! $(command -v xz) ]]; then
#        echo "XZ not found. Attempting to install..."
#        sudo apt update
#        sudo apt install -y xz-utils
#    fi
#    wget https://gtg.eos.house/get/blockchain.xz/block_log.xz -O $DATADIR/witness_node_data_dir/blockchain/block_log.xz
#    echo "Decompressing block log... this may take a while..."
#    xz -d $DATADIR/witness_node_data_dir/blockchain/block_log.xz
#    echo "FINISHED. Blockchain downloaded and decompressed"
#    echo "Remember to resize your /dev/shm, and run with replay!"
#    echo "$ ./run.sh shm_size SIZE (e.g. 8G)"
#    echo "$ ./run.sh replay"
#}

install_docker() {
    sudo apt update
    sudo apt install curl git
    curl https://get.docker.com | sh
    if [ "$EUID" -ne 0 ]; then 
        echo "Adding user $(whoami) to docker group"
        sudo usermod -aG docker $(whoami)
        echo "IMPORTANT: Please re-login (or close and re-connect SSH) for docker to function correctly"
    fi
}

install() {
    echo "Loading image from someguy123/eos"
    docker pull someguy123/eos
    echo "Tagging as eos"
    docker tag someguy123/eos eos
    echo "Installation completed. You may now configure or run the server"
}

seed_exists() {
    seedcount=$(docker ps -a -f name="^/"$DOCKER_NAME"$" | wc -l)
    if [[ $seedcount -eq 2 ]]; then
        return 0
    else
        return -1
    fi
}

seed_running() {
    seedcount=$(docker ps -f 'status=running' -f name=$DOCKER_NAME | wc -l)
    if [[ $seedcount -eq 2 ]]; then
        return 0
    else
        return -1
    fi
}

start() {
    echo $GREEN"Starting container..."$RESET
    seed_exists
    if [[ $? == 0 ]]; then
        docker start $DOCKER_NAME
    else
        docker run ${DPORTS[@]} -v /dev/shm:/shm -v "$DATADIR":"$MOUNTDIR" -d --name $DOCKER_NAME -t eos start_eosd.sh
    fi
}

replay() {
    echo "Removing old container"
    docker rm $DOCKER_NAME
    echo "Running eos with replay..."
    docker run ${DPORTS[@]} -v /dev/shm:/shm -v "$DATADIR":"$MOUNTDIR" -d --name $DOCKER_NAME -t eos eosd --replay
    echo "Started."
}

shm_size() {
    echo "Setting SHM to $1"
    mount -o remount,size=$1 /dev/shm
}

stop() {
    echo $RED"Stopping container..."$RESET
    docker stop $DOCKER_NAME
    docker rm $DOCKER_NAME
}

enter() {
    docker exec -it $DOCKER_NAME bash
}

wallet() {
    docker exec -it $DOCKER_NAME eosc wallet "${@}"
}

client() {
    docker exec -it $DOCKER_NAME eosc "${@}"
}

remote_wallet() {
    docker run -v "$DATADIR":"$MOUNTDIR" --rm -it eos eosc -H testnet1.eos.io -p 80 wallet "${@}"
}

logs() {
    echo $BLUE"DOCKER LOGS: "$RESET
    docker logs --tail=30 $DOCKER_NAME
    #echo $RED"INFO AND DEBUG LOGS: "$RESET
    #tail -n 30 $DATADIR/{info.log,debug.log}
}

status() {
    
    seed_exists
    if [[ $? == 0 ]]; then
        echo "Container exists?: "$GREEN"YES"$RESET
    else
        echo "Container exists?: "$RED"NO (!)"$RESET 
        echo "Container doesn't exist, thus it is NOT running. Run $0 build && $0 start"$RESET
        return
    fi

    seed_running
    if [[ $? == 0 ]]; then
        echo "Container running?: "$GREEN"YES"$RESET
    else
        echo "Container running?: "$RED"NO (!)"$RESET
        echo "Container isn't running. Start it with $0 start"$RESET
        return
    fi

}

if [ "$#" -lt 1 ]; then
    help
fi

case $1 in
    build)
        echo "You may want to use '$0 install' for a binary image instead, it's faster."
        build
        ;;
    build_full)
        echo "You may want to use '$0 install_full' for a binary image instead, it's faster."
        build_full
        ;;
    install_docker)
        install_docker
        ;;
    install)
        install
        ;;
    install_full)
        install_full
        ;;
    start)
        start
        ;;
    replay)
        replay
        ;;
    shm_size)
        shm_size $2
        ;;
    stop)
        stop
        ;;
    restart)
        stop
        sleep 5
        start
        ;;
    rebuild)
        stop
        sleep 5
        build
        start
        ;;
    optimize)
        echo "Applying recommended dirty write settings..."
        optimize
        ;;
    status)
        status
        ;;
    wallet)
        shift
        wallet "${@}"
        ;;
    remote_wallet)
        shift
        remote_wallet "${@}"
        ;;
    client)
        shift
        client "${@}"
        ;;
    dlblocks)
        dlblocks 
        ;;
    enter)
        enter
        ;;
    logs)
        logs
        ;;
    *)
        echo "Invalid cmd"
        help
        ;;
esac
