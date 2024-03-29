#!/bin/bash
# Copyright 2020 Huawei Technologies Co., Ltd
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
# echo "Usage: sh run_distribute_train.sh [DATASET_PATH] [PRETRAINED_BACKBONE] [RANK_TABLE_FILE]"
# ============================================================================

if [ $# != 1 ]
then
    echo "Usage: sh run_distribute_train.sh [DATASET_PATH]"
exit 1
fi

get_real_path(){
  if [ "${1:0:1}" == "/" ]; then
    echo "$1"
  else
    echo "$(realpath -m $PWD/$1)"
  fi
}

DATASET_PATH=$(get_real_path $1)
# PRETRAINED_BACKBONE=$(get_real_path $2)
# RANK_TABLE_FILE=$(get_real_path $3)
echo $DATASET_PATH
# echo $PRETRAINED_BACKBONE
# echo $RANK_TABLE_FILE

if [ ! -d $DATASET_PATH ]
then
    echo "error: DATASET_PATH=$DATASET_PATH is not a directory"
exit 1
fi

# if [ ! -f $PRETRAINED_BACKBONE ]
# then
#     echo "error: PRETRAINED_PATH=$PRETRAINED_BACKBONE is not a file"
# exit 1
# fi

# if [ ! -f $RANK_TABLE_FILE ]
# then
#     echo "error: RANK_TABLE_FILE=$RANK_TABLE_FILE is not a file"
# exit 1
# fi

export DEVICE_NUM=2
export RANK_SIZE=2
# export RANK_TABLE_FILE=$RANK_TABLE_FILE
# export MINDSPORE_HCCL_CONFIG_PATH=$RANK_TABLE_FILE

cpus=`cat /proc/cpuinfo| grep "processor"| wc -l`
avg=`expr $cpus \/ $RANK_SIZE`
gap=`expr $avg \- 1`

for((i=0; i<${DEVICE_NUM}; i++))
do
    start=`expr $i \* $avg`
    end=`expr $start \+ $gap`
    cmdopt=$start"-"$end

    export DEVICE_ID=$i
    export RANK_ID=$i
    rm -rf ./train_parallel$i
    mkdir ./train_parallel$i
    cp ../*.py ./train_parallel$i
    cp ../*.yaml ./train_parallel$i
    cp -r ../src ./train_parallel$i
    cp -r ../model_utils ./train_parallel$i
    cd ./train_parallel$i || exit
    echo "start training for rank $RANK_ID, device $DEVICE_ID"
    env > env.log
    taskset -c $cmdopt python train.py \
        --data_dir=$DATASET_PATH \
        # --pretrained_backbone=$PRETRAINED_BACKBONE \
        --is_distributed=1 \
        --lr=0.012 \
        --t_max=5 \
        --max_epoch=5 \
        --warmup_epochs=4 \
        --per_batch_size=8 \
        --lr_scheduler=cosine_annealing  > log.txt 2>&1 &
    cd ..
done
