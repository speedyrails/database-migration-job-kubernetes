# Database Migration Job for Kubernetes

Creates a Kubernetes Job to run database migrations.

## Requirements

- The `kubectl` command line must be installed on the system. For [AWS EKS](https://docs.aws.amazon.com/eks/latest/userguide/install-kubectl.html) and for [normal Kubernetes](https://kubernetes.io/docs/tasks/tools/install-kubectl/).
- Access to a Kubernetes cluster to run the job.

## Usage

Download the script and apply the execution permissions:

```bash
curl -L https://github.com/speedyrails/database-migration-job-kubernetes/raw/main/db-migration-job.sh -o db-migration-job.sh
chmod +x db-migration-job.sh
```

The script expects the following arguments:

- `OCI_IMAGE:TAG`: the OCI image to use in the job.
- `K8s CONFIG MAP LIST`: a Kubernetes configmaps name list separated by spaces with the environment variables required by the app.
- `COMMAND_ENTRYPOINT`: the entrypoint used by the job.
- `COMMAND_ARGUMENT`: the arguments passed to the entrypoint.

A optional argument can be passed to the script:

- `MIGRATION_TIMEOUT`: the length of time to wait before giving up. Zero means check once and don't wait, negative means wait for a week. The value must be in seconds. If not timeout provided the default value is 600 seconds.

To execute the job for database migrations:

```bash
./db-migration-job.sh "OCI_IMAGE:TAG" "K8s CONFIGMAP NAME LIST SEPARATED BY SPACES" "COMMAND_ENTRYPOINT" "COMMAND_ARGUMENT" "MIGRATION_TIMEOUT_SECONDS"
```

## Examples

For apps built with [Cloud Native Buildpacks](https://buildpacks.io/), define the `COMMAND_ENTRYPOINT` as `/cnb/lifecycle/launcher` and `COMMAND_ARGUMENT` as `bundle exec rake db:migrate`; for instance:

```bash
./db-migration-job.sh "myapp:latest" "cm1 cm2 cm3" "/cnb/lifecycle/launcher" "bundle exec rake db:migrate"
```

For others build you can use `/bin/bash` or `/bin/sh` as the `COMMAND_ENTRYPOINT`; for instance:

```bash
./db-migration-job.sh "myapp:latest" "cm1 cm2 cm3" "/bin/bash" "bundle exec rake db:migrate"
```

To run a migration and wait 300 seconds for it to finish:

```bash
./db-migration-job.sh "myapp:latest" "cm1 cm2 cm3" "/bin/bash" "bundle exec rake db:migrate" "300"
```

## License

MIT

## Author Information

[Speedyrails Inc.](https://www.speedyrails.com/)

By: [Carlos M Bustillo Rdguez](https://linkedin.com/in/carlosbustillordguez/)
