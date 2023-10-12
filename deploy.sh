#!/bin/sh


### Source (load) the .env file to set the environment variables

root_directory="$(pwd)"
env_file="$root_directory/.env"
if [ -f "$env_file" ]; then
    source "$env_file"
else
    echo "Error: .env file not found in the current directory."
    exit 1
fi


### Create and set S3 Bucket

bucket_name=$PROJECT_NAME
if ! aws s3api head-bucket --bucket $bucket_name 2>/dev/null; then
  echo "Creating S3 bucket: $bucket_name in $AWS_REGION"
  aws s3api create-bucket \
    --bucket $bucket_name \
    --region $AWS_REGION > /dev/null
else
  echo "S3 bucket $bucket_name already exists."
fi


### Prepare and upload functions to S3

functions_directory="$root_directory/functions"
for function_folder in "$functions_directory"/*; do
    if [ -d "$function_folder" ]; then
        function_name=$(basename "$function_folder")
        aws_function_name=${PROJECT_NAME}_${function_name}
        cd "$function_folder"
        echo "Bundle $function_name"
        bundle config set --local path 'vendor/bundle'
        bundle install > /dev/null
        echo "Zip to $aws_function_name.zip"
        zip -r "$aws_function_name.zip" lambda_function.rb vendor/ lib/ > /dev/null
        echo "Upload to S3 bucket $bucket_name"
        aws s3 cp "$aws_function_name.zip" s3://$bucket_name/functions/ > /dev/null
    fi
done


### Create or update secrets

create_or_update_secret() {
    local secret_name="$1"
    local secret_string="$2"

    # Check if the secret exists
    if aws secretsmanager describe-secret --secret-id "$secret_name" >/dev/null 2>&1; then
        # Secret exists, update it
        echo "Updating secret: $secret_name"
        aws secretsmanager update-secret --secret-id "$secret_name" --secret-string "$secret_string" > /dev/null
        echo "Secret updated successfully"
    else
        # Secret doesn't exist, create it
        echo "Creating secret: $secret_name"
        aws secretsmanager create-secret --name "$secret_name" --secret-string "$secret_string" > /dev/null
        echo "Secret created successfully"
    fi
}
SECRET_NAME=$PROJECT_NAME
SECRET_DATA="{\"open_weather_api_key\":\"${OPEN_WEATHER_API_KEY}\"}"
create_or_update_secret "$SECRET_NAME" "$SECRET_DATA"


### Apply cloudformation stack

cd "$root_directory"
stack_name=$PROJECT_NAME
template_file="stack.yml"
parameters="
ParameterKey=ProjectName,ParameterValue=$PROJECT_NAME
ParameterKey=AwsRuntime,ParameterValue=$AWS_RUNTIME"

# Check if the stack exists
if aws cloudformation describe-stacks --stack-name $stack_name &>/dev/null; then
  # Stack exists, update it
  echo "Updating CloudFormation stack $stack_name..."
  aws cloudformation update-stack \
    --stack-name $stack_name \
    --template-body file://$template_file \
    --capabilities CAPABILITY_NAMED_IAM \
    --parameters $parameters > /dev/null
  echo "Stack update in progress..."

  # Wait for the update to complete
  aws cloudformation wait stack-update-complete --stack-name $stack_name
  echo "Stack update complete."
else
  # Stack doesn't exist, create it
  echo "Stack $stack_name does not exist. Creating a new CloudFormation stack..."
  aws cloudformation create-stack \
    --stack-name $stack_name \
    --template-body file://$template_file \
    --capabilities CAPABILITY_NAMED_IAM \
    --parameters $parameters > /dev/null
  echo "Stack creation in progress..."

  # Wait for the creation to complete
  aws cloudformation wait stack-create-complete --stack-name $stack_name
  echo "Stack creation complete."
fi
