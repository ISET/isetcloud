#!/bin/bash
cd /Users/eugeneliu/git_repo/tensorflow/models/research

export YOUR_GCS_BUCKET=${machine-driving-20180115-ml}
# download data and annotations
wget http://www.robots.ox.ac.uk/~vgg/data/pets/data/images.tar.gz
wget http://www.robots.ox.ac.uk/~vgg/data/pets/data/annotations.tar.gz
tar -xvf images.tar.gz
tar -xvf annotations.tar.gz

# convert pet format to tf-format
python object_detection/dataset_tools/create_pet_tf_record.py \
    --label_map_path=object_detection/data/pet_label_map.pbtxt \
    --data_dir=`pwd` \
    --output_dir=`pwd`
# Add gsutil to path
source /usr/local/bin/google-cloud-sdk/path.bash.inc
# upload data to cloud storage

gsutil cp pet_train_with_masks.record gs://${YOUR_GCS_BUCKET}/data/pet_train.record
gsutil cp pet_val_with_masks.record gs://${YOUR_GCS_BUCKET}/data/pet_val.record
gsutil cp object_detection/data/pet_label_map.pbtxt gs://${YOUR_GCS_BUCKET}/data/pet_label_map.pbtxt

# download a coco-pretrained model
wget http://storage.googleapis.com/download.tensorflow.org/models/object_detection/faster_rcnn_resnet101_coco_11_06_2017.tar.gz
tar -xvf faster_rcnn_resnet101_coco_11_06_2017.tar.gz
gsutil cp faster_rcnn_resnet101_coco_11_06_2017/model.ckpt.* gs://${YOUR_GCS_BUCKET}/data/

# Edit the faster_rcnn_resnet101_pets.config template. Please note that there
# are multiple places where PATH_TO_BE_CONFIGURED needs to be set to the working dir. 
sed -i '' "s|PATH_TO_BE_CONFIGURED|"gs://${YOUR_GCS_BUCKET}"/data|g" \
    object_detection/samples/configs/faster_rcnn_resnet101_pets.config

# Copy edited template to cloud.
gsutil cp object_detection/samples/configs/faster_rcnn_resnet101_pets.config \
    gs://${YOUR_GCS_BUCKET}/data/faster_rcnn_resnet101_pets.config


#check cloud storage: https://console.cloud.google.com/storage/browser?project=machine-driving-20180115

# package Tensorflow Object Detection code
python setup.py sdist
cd slim && python setup.py sdist
cd .. # back to previous folder

# Start Training

gcloud ml-engine jobs submit training `whoami`_object_detection_`date +%s` \
    --runtime-version 1.2 \
    --job-dir=gs://${YOUR_GCS_BUCKET}/train \
    --packages dist/object_detection-0.1.tar.gz,slim/dist/slim-0.1.tar.gz \
    --module-name object_detection.train \
    --region us-central1 \
    --config object_detection/samples/cloud/cloud.yml \
    -- \
    --train_dir=gs://${YOUR_GCS_BUCKET}/train \
    --pipeline_config_path=gs://${YOUR_GCS_BUCKET}/data/faster_rcnn_resnet101_pets.config

# Start evaluation concurrently

gcloud ml-engine jobs submit training `whoami`_object_detection_eval_`date +%s` \
    --runtime-version 1.2 \
    --job-dir=gs://${YOUR_GCS_BUCKET}/train \
    --packages dist/object_detection-0.1.tar.gz,slim/dist/slim-0.1.tar.gz \
    --module-name object_detection.eval \
    --region us-central1 \
    --scale-tier BASIC_GPU \
    -- \
    --checkpoint_dir=gs://${YOUR_GCS_BUCKET}/train \
    --eval_dir=gs://${YOUR_GCS_BUCKET}/eval \
    --pipeline_config_path=gs://${YOUR_GCS_BUCKET}/data/faster_rcnn_resnet101_pets.config

# Monitor Progress with Tensorboard, for the first time.
gcloud auth application-default login

tensorboard --logdir=gs://${YOUR_GCS_BUCKET}
# Then Navigate to 'localhost:6006'
#Please note it may take Tensorboard a couple minutes to populate with data.







