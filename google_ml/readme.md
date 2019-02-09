### Dataset Preparation
If you are using a mac, you should be careful when you convert your images/labels into tfRecord files, because mac automatically create a hidden file named '.DS_Store', which you should delete before run the python convert function.
Under your source directory, run this: 

`find . -name .DS_Store -type f -delete`

### Tip1:

For tensorflow v1.8, you need pycocotools to utilize coco metrics on your evaluation process.

Besides following the [general installation guide](https://github.com/tensorflow/models/blob/master/research/object_detection/g3doc/installation.md), there are some known and unsolved issues caused by tensorflow(v1.8), you should manually include pycocotools when submitting an evaluation job to cloud. Download pycocotools-2.0.tar.gz [here](https://drive.google.com/file/d/1RvJLThYSs7LnOSBN5YyyKo1UhJBrZVOf/view?usp=sharing).

We suggest you put it under `./models/research/object_detection`.

### Tip2:

We found that you can include following lines in your .bash_profile to correctly call gcloud and gsutil everytime. Be sure to change the right path to where you store the google cloud SDK.
```
# The next line updates PATH for the Google Cloud SDK.
if [ -f '/path/to/google-cloud-sdk/path.bash.inc' ]; then source '/Users/zhenyiliu/google-cloud-sdk/path.bash.inc'; fi

# The next line enables shell command completion for gcloud.
if [ -f '/path/to/google-cloud-sdk/completion.bash.inc' ]; then source '/Users/zhenyiliu/google-cloud-sdk/completion.bash.inc'; fi
```

### Tip3:

You should examine the config file before you submit your training / evaluation jobs. 
```
train_input_reader: {
  tf_record_input_reader {
    input_path: "PATH_TO_BE_CONFIGURED/train.record" # Change to train.record
  }
  label_map_path: "PATH_TO_BE_CONFIGURED/label_map.pbtxt" # Change to label_map.pbtxt
}
```
```
eval_config: {
  num_examples: 1500 # Change to match the size of your evaluation dataset
  # Note: The below line limits the evaluation process to 10 evaluations.
  # Remove the below line to evaluate indefinitely.
  max_evals: 10 #

```
```
eval_input_reader: {
  tf_record_input_reader {
    input_path: "PATH_TO_BE_CONFIGURED/val.record" # Change to val.record
  }
  label_map_path: "PATH_TO_BE_CONFIGURED/label_map.pbtxt" # Change to label_map.pbtxt
  shuffle: false
  num_readers: 1
}
```
### Others
Try to install protobuf3
```
coronal:~ zhenyiliu$ pip install protobuf3
Collecting protobuf3
  Downloading https://files.pythonhosted.org/packages/6d/26/955c07e16200d20de70b1e17b246e0574a517b76d6e6393d8ef7ce4f38cd/protobuf3-0.2.1.tar.gz
Building wheels for collected packages: protobuf3
  Running setup.py bdist_wheel for protobuf3 ... done
  Stored in directory: /Users/zhenyiliu/Library/Caches/pip/wheels/38/24/a4/5c5271e794df2d16b27626921dcd437ab75ade71bb5f0f362d
Successfully built protobuf3
Installing collected packages: protobuf3
Successfully installed protobuf3-0.2.1
```
For python-tk, maybe we should go to https://www.python.org/downloads/release/python-2715/ and download the installation package.
To verify your installation, try
```
python
import Tkinker
```
If no errors occured, congratulations!

### We have created a new machine-learning instance for running tasks like pytorch models and keras models
We cloned the ubuntu image from Stanford cs231n, which includes following frameworks as described on this [page](http://cs231n.github.io/gce-tutorial/).

- [Anaconda3](https://www.anaconda.com/what-is-anaconda/), a python package manager. You can think of it as a better alternative to `pip`. 
- Numpy, matplotlib, and tons of other common scientific computing packages.
- [Tensorflow 1.7](https://www.tensorflow.org/), both CPU and GPU. 
- [PyTorch 0.3](https://www.pytorch.org/), both CPU and GPU. 
- [Keras](https://keras.io/) that works with Tensorflow 1.7
- [Caffe2](https://caffe2.ai/), CPU only. Note that it is very different from the original Caffe. 
- Nvidia runtime: CUDA 9.0 and cuDNN 7.0. They only work when you create a Cloud GPU instance, which we will cover later. 

Run following commands in your terminal to access to the instance: 
    
    # Set your project to be machine drving 20180115
    gcloud config set project machine-driving-20180115
    # SSH to the instance
    gcloud compute ssh --zone=us-west1-b machine-learning
    
Upon your first ssh, you need to run a one-time setup script and reload the .bashrc to activate the libraries. The exact command is

    /home/shared/setup.sh && source ~/.bashrc

You are able to configure the number of gpus you like to use, add disk storage to store your datasets [here with gcould GUI](https://console.cloud.google.com/compute/instances?project=machine-driving-20180115). 

Once you logged in, run`jupyter-notebook --no-browser --port=7000`, you will get a url like
`http://localhost:7000/?token=xxxxxxxxxxxxxxxxx`, just replace "localhost" with "35.277.146.166", then visit the url on your local browser. 
Now you can run your machine learning tasks with jupyter notebook.

#### 02/08/2019 tensorflow doesnot work on distributed GPUs, so I am switching to pytorch
Facebook has a github branch named [maskrcnn-benchmark](https://github.com/facebookresearch/maskrcnn-benchmark) providing faster rcnn and maskrcnn pretrained models and training & evaluation tools.
## Note
I am using cuda9.2 cudnn7.2 pytorch-nightly with cuda92: conda install pytorch-nightly cuda92 -c pytorch



