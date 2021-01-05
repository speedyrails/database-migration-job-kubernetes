#!/bin/sh
#
# Creates a Kubernetes Job to run database migrations.
#
# Usage:
#   ./db-migration-job.sh "OCI_IMAGE:TAG" "K8s CONFIGMAP NAME LIST SEPARATED BY SPACES" "COMMAND_ENTRYPOINT" "COMMAND_ARGUMENT"
#
# Example:
#   db-migration-job.sh "myapp:latest" "cm1 cm2 cm3" "/cnb/lifecycle/launcher" "bundle exec rake db:migrate" "300"
# 
# By Carlos Miguel Bustillo Rdguez <https://linkedin.com/in/carlosbustillordguez/>
# Speedyrails Inc. <https://www.speedyrails.com/>
#
# Version: 1.0.0 (Tue 05 Jan 2021 03:24:33 PM GMT)

## Variables
# Random ID
RANDOM_ID=$(tr -cd a-z0-9 < /dev/urandom | fold -w8 | head -n1)

# Job name
JOB_NAME="db-migration-${RANDOM_ID}"

# Migration Timeout in seconds
MIGRATION_TIMEOUT="${5:-"600"}"

## Check arguments
if [ -z "$1" ] || [ -z "$2" ] || [ -z "$3" ] || [ -z "$4" ]; then
    echo "$(basename "$0"): Missing arguments or not arguments passed."
    echo "Usage:"
    echo "  ./db-migration-job.sh \"OCI_IMAGE:TAG\" \"K8s CONFIGMAP NAME LIST SEPARATED BY SPACES\" \"COMMAND_ENTRYPOINT\" \"COMMAND_ARGUMENT\" \"MIGRATION_TIMEOUT_SECONDS\""
    echo "Example:"
    echo "  ./db-migration-job.sh \"myapp:latest\" \"cm1 cm2 cm3\" \"/bin/bash\" \"bundle exec rake db:migrate\" \"300\""
    exit 1
else
    IMAGE_WITH_TAG="$1"
    CONFIGMAP_NAME_LIST="$2"
    COMMAND_ENTRYPOINT="$3"
    COMMAND_ARGUMENT="$4"
fi

## Check if kubectl is installed in the system
if ! which kubectl >/dev/null 2>&1; then
    echo "The 'kubectl' CLI is not installed in the system. Please check one of the following links to install it:"
    echo " - https://kubernetes.io/docs/tasks/tools/install-kubectl/"
    echo " - https://docs.aws.amazon.com/eks/latest/userguide/install-kubectl.html"
    exit 1
fi

## Create the job template

if [ "$COMMAND_ENTRYPOINT" = "/cnb/lifecycle/launcher" ]; then

cat <<EOF > db-migration-job.yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: ${JOB_NAME}
spec:
  backoffLimit: 0
  template:
    metadata:
      name: ${JOB_NAME}
    spec:
      containers:
      - name: ${JOB_NAME}
        image: $IMAGE_WITH_TAG
        command: [ "$COMMAND_ENTRYPOINT", "$COMMAND_ARGUMENT" ]
        envFrom:
EOF

else

cat <<EOF > db-migration-job.yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: ${JOB_NAME}
spec:
  backoffLimit: 0
  template:
    metadata:
      name: ${JOB_NAME}
    spec:
      containers:
      - name: ${JOB_NAME}
        image: $IMAGE_WITH_TAG
        command: [ "$COMMAND_ENTRYPOINT" ]
        args: [ "-c", "$COMMAND_ARGUMENT" ]
        envFrom:
EOF

fi

# Add the ConfigMaps to the job template
for CONFIGMAP_NAME in ${CONFIGMAP_NAME_LIST}; do
    echo "        - configMapRef:" >> db-migration-job.yaml
    echo "            name: $CONFIGMAP_NAME" >> db-migration-job.yaml
done

# Define the restart policy for the job template
echo "      restartPolicy: Never" >> db-migration-job.yaml

## Kubernetes tasks

# Create job for data migration
kubectl create -f db-migration-job.yaml

# Wait until the migration process finishes
kubectl wait --for=condition=complete --timeout="${MIGRATION_TIMEOUT}"s job/"${JOB_NAME}"

# Get the data migration job logs
DATA_MIGRATION_POD_ID=$(kubectl get pods --no-headers -o custom-columns=":metadata.name" -l job-name="${JOB_NAME}")
echo "### Data migration ouput logs ###"
kubectl logs "$DATA_MIGRATION_POD_ID" --since=1h

# Check if the job (pod) has succeeded
JOB_STATUS=$(kubectl get job "${JOB_NAME}" --no-headers -o custom-columns=":status.conditions[0].type")

if [ "$JOB_STATUS" = "Complete" ]; then
    echo "The database migration process is completed!!!"
    kubectl delete job "${JOB_NAME}"
    exit 0
else
    echo "The database migration process has failed!!!"
    kubectl delete job "${JOB_NAME}"
    exit 1
fi
