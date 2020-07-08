# n0

## Background

Did you ever play pass the parcel? You can read about it here: https://en.wikipedia.org/wiki/Pass_the_parcel

This is a wrapper script, for a wrapper script, oh never mind. 

This orchestrates the creation of AWS infrastructure to host the Notejam application.

You can read about Notejam here: https://github.com/komarserjio/notejam

## Usage

```
git clone https://github.com/ncdemo2020/n0.git
pushd n0
./invoke.sh -h
```

Isn't the worst place to start. Can you align yourself with the assumptions and prerequisites? Isn't that some key name?

Your milage may vary. Some journeys benefit from:

```
aws iam list-instance-profiles | jq '.InstanceProfiles[].InstanceProfileName'
aws iam delete-instance-profile --instance-profile-name
```

If cloudformation stacks continue to fail to delete, consider to review the Autoscaling groups that exist. You may need to delete this manually.


If you know, you know.

