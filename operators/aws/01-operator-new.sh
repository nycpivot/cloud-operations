#!/bin/bash

read -p "Stack Name (aws-operator-stack): " stack_name
read -p "Operator Name (aws-operator): " operator_name
read -p "AWS Region Code (us-east-1): " aws_region_code

if [[ -z $stack_name ]]
then
	stack_name=aws-operator-stack
fi

if [[ -z $operator_name ]]
then
	operator_name=aws-operator
fi

if [[ -z $aws_region_code ]]
then
	aws_region_code=us-east-1
fi

vpc_id=$(aws ec2 describe-vpcs --region ${aws_region_code} --filter "Name=isDefault,Values=true" --query "Vpcs[].VpcId" --output text)

if [[ -z $vpc_id ]]
then
	read -p "VPC Id: " vpc_id
fi

aws cloudformation create-stack \
	--stack-name ${stack_name} \
	--region ${aws_region_code} \
	--parameters ParameterKey=OperatorName,ParameterValue=${operator_name} \
	--parameters ParameterKey=VpcId,ParameterValue=${vpc_id} \
	--template-body file://operators/aws/config/operator-stack.yaml

aws cloudformation wait stack-create-complete --stack-name ${stack_name} --region ${aws_region_code}

key_id=$(aws ec2 describe-key-pairs --filters Name=key-name,Values=aws-operator-keypair --query KeyPairs[*].KeyPairId --output text --region ${aws_region_code})

if [ ! -d "operators/aws/keys" ]
then
	mkdir operators/aws/keys
fi

if test -f operators/aws/keys/aws-operator-keypair-${aws_region_code}.pem; then
	rm operators/aws/keys/aws-operator-keypair-${aws_region_code}.pem
fi

aws ssm get-parameter --name " /ec2/keypair/${key_id}" --with-decryption \
	--query Parameter.Value --region ${aws_region_code} \
	--output text > operators/aws/keys/aws-operator-keypair-${aws_region_code}.pem

echo

aws cloudformation describe-stacks \
	--stack-name ${stack_name} \
	--region ${aws_region_code} \
	--query "Stacks[0].Outputs[?OutputKey=='PublicDnsName'].OutputValue" --output text

