#!/bin/bash

set -eo pipefail

MOUNT_DIR=/opt/svsm-vtpm
LOG_FILE=${HOME}/svsm-vtpm-setup.log

ARTIFACT_REPO="SVSM-vTPM-artifacts"

USER=${SUDO_USER}

if [[ ${USER} == "" ]]; then
  USER=$(id -u -n)
fi

if [[ ${SUDO_GID} == "" ]]; then
  GROUP=$(id -g -n)
else
  GROUP=$(getent group  | grep ${SUDO_GID} | cut -d':' -f1)
fi

record_log() {
  echo "[$(date)] $1" >> ${LOG_FILE}
}

create_extfs() {
  record_log "Creating ext4 filesystem on /dev/sda4"
  sudo mkfs.ext4 -Fq /dev/sda4
}

mountfs() {
  sudo mkdir -p ${MOUNT_DIR}
  sudo mount -t ext4 /dev/sda4 ${MOUNT_DIR}

  if [[ $? != 0 ]]; then
    record_log "Partition might be corrupted"
    create_extfs
    mountfs
  fi

  sudo chown -R ${USER}:${GROUP} ${MOUNT_DIR}
}

delete_swap() {
  record_log "Deleting swap partition ..."
  sudo swapoff -a
  # Delete SWAP parition. check GUID: https://en.wikipedia.org/wiki/GUID_Partition_Table
  sudo sfdisk -d /dev/sda | grep -v 'type=0657FD6D-A4AB-43C4-84E5-0933C84B4F4F' | sudo sfdisk -f /dev/sda
}

create_new_partition() {
  record_log "Creating new data partition..."
  END_SECTOR=$(($(sudo sfdisk -l -o End /dev/sda | tail -n 1) + 1))
  # GUID of a regular linux partition
  echo "${END_SECTOR}+,0FC63DAF-8483-4772-8E79-3D69D8477DE4" | sudo sfdisk -f -a /dev/sda

  # activate partition
  sudo partprobe /dev/sda
}

prepare_local_partition() {
  record_log "Preparing local partition ..."

  delete_swap
  create_new_partition

  MOUNT_POINT=$(mount -v | grep "/dev/sda4" | awk '{print $3}' ||:)

  if [[ x"${MOUNT_POINT}" == x"${MOUNT_DIR}" ]];then
    record_log "/dev/sda4 is already mounted on ${MOUNT_POINT}"
    return
  fi

  if [ x$(sudo file -sL /dev/sda4 | grep -o ext4) == x"" ]; then
    create_extfs;
  fi

  mountfs
}

prepare_machine() {
  record_log "Prepare_machine";
  prepare_local_partition
}

# Clone all repos
clone_artifacts() {
  if [ ! -d ${MOUNT_DIR}/${ARTIFACT_REPO} ]; then
    record_log "Cloning artifacts"
    pushd ${MOUNT_DIR}
    git clone https://github.com/svsm-vtpm/${ARTIFACT_REPO}
    popd;
  else
    record_log "${ARTIFACT_REPO} dir not empty! skipping..."
  fi
}


clone_repos() {
  record_log "Clone repos";
  clone_artifacts
}

## Build
build_all() {
  record_log "Setting up the host"
  pushd ${MOUNT_DIR}/${ARTIFACT_REPO}
  ./prepare.sh init
  ./prepare.sh install
  popd
}

prepare_machine;
clone_repos;
build_all;
record_log "Done Setting up!"
