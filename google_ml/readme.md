### Tip1:

For tensorflow v1.8, you need pycocotools to utilize coco metrics on your evaluation process.

Besides following the [general installation guide](https://github.com/tensorflow/models/blob/master/research/object_detection/g3doc/installation.md), there are some known and unsolved issues caused by tensorflow(v1.8), you should manually include pycocotools when submitting an evaluation job to cloud. Download pycocotools-2.0.tar.gz [here](https://drive.google.com/file/d/1RvJLThYSs7LnOSBN5YyyKo1UhJBrZVOf/view?usp=sharing).

We suggest you put it under `./models/research/object_detection`.

### Tip2:

We found that you can include following lines in your .bash_profile to correctly call gcloud and gsutil everytime. Be sure to change the right path to where you store the google cloud SDK.
```# The next line updates PATH for the Google Cloud SDK.
if [ -f '/path/to/google-cloud-sdk/path.bash.inc' ]; then source '/Users/zhenyiliu/google-cloud-sdk/path.bash.inc'; fi

# The next line enables shell command completion for gcloud.
if [ -f '/path/to/google-cloud-sdk/completion.bash.inc' ]; then source '/Users/zhenyiliu/google-cloud-sdk/completion.bash.inc'; fi```
