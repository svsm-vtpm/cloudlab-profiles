#!/bin/bash 

VERBOSE_LOG=${HOME}/svsm-vtpm-verbose.log

echo "Logging to ${VERBOSE_LOG}"
/local/repository/svsm-vtpm-setup.sh |& tee -a ${VERBOSE_LOG}
