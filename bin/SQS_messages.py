#!/usr/bin/env python
#### 2021-05-27 10:18:40 MNJ
#### This script will send/receive a message to a specific CovidSeq AWS/SQS queue.
#### Message content will be the Basespace project name containing covidseq sequences that need to be analyzed.


#### Sending a message to queue will be performed by covidseq app or any other source
#### This script will periodically read SQS and activate analysis based on data availability and SQS messages.


#### Receiving a message will activate data download analysos

#### Dleeting message from queue when analysis finished successfully.
import boto3
import os
from tendo import singleton ### To ensure single execution

#### Will exit if another instance running
me = singleton.SingleInstance()


print(os.path.dirname(os.path.realpath(__file__)))
myDir=os.path.dirname(os.path.realpath(__file__))
sqs = boto3.client('sqs')
queue_url = 'https://sqs.eu-west-1.amazonaws.com/444390077361/CovidSeq'
# Receive message from SQS queue
response = sqs.receive_message(
    QueueUrl=queue_url,
    AttributeNames=[
        'SentTimestamp'
    ],
    MaxNumberOfMessages=1,
    MessageAttributeNames=[
        'All'
    ],
    VisibilityTimeout=0,
    WaitTimeSeconds=0
)
print(response)
>>>>>>> 7433857f4edeb14e5a44f2ae1923a8aaa58c0f05
message = response['Messages'][0]
receipt_handle = message['ReceiptHandle']
myArg=(message['Body'])
#print('Received message: %s' % message)
print(myArg)

bashCommand = myDir+"/fetchAndUpload.sh "+myArg
print(bashCommand)
import subprocess
#process = subprocess.Popen(bashCommand.split(), stdout=subprocess.PIPE)
process = subprocess.Popen(bashCommand.split())
output, error = process.communicate()

# Delete received message from queue
sqs.delete_message(
    QueueUrl=queue_url,
    ReceiptHandle=receipt_handle
)
