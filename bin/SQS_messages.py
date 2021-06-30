#!/usr/bin/env python
#### 2021-05-27 10:18:40 MNJ
#### This script will send/receive a message to a specific CovidSeq AWS/SQS queue.
#### Message content will be the Basespace project name containing covidseq sequences that need to be analyzed.


#### Sending a message to queue will be performed by covidseq app or any other source
#### This script will periodically read SQS and activate analysis based on data availability and SQS messages.

### SES e-mail will eb sent at analsis start and end.cd bin
import boto3
from botocore.exceptions import ClientError
import sys,os
import subprocess
from pathlib import Path
pathname = os.path.abspath(os.path.dirname(sys.argv[0]) )
from tendo import singleton ### To ensure single execution

#### Will exit if another instance running
me = singleton.SingleInstance()


sqs = boto3.client('sqs')
queue_url = 'https://sqs.eu-west-1.amazonaws.com/444390077361/CovidSeq'
# Receive message from SQS queue
response = sqs.receive_message(
    QueueUrl=queue_url,
    AttributeNames=[
        'SentTimestamp'
    ],
    MaxNumberOfMessages=10,
    MessageAttributeNames=[
        'All'
    ],
    VisibilityTimeout=10,
    WaitTimeSeconds=0
)
#print(response.get('Messages'))
print(f"Number of messages received: {len(response.get('Messages', []))}")
if len(response.get('Messages', [])) == 0:
    print("No messages from SQS, exiting...")
    exit()

message = response['Messages'][0]
print(message)
receipt_handle = message['ReceiptHandle']
myArg=(message['Body'])
print(myArg)
# Creates a new file
with open('/tmp/covid_projects_pending.txt', 'a') as fp:
    fp.write(myArg+",pending\n")
    
sqs.delete_message(
    QueueUrl=queue_url,
    ReceiptHandle=receipt_handle
    )


    # To write data to new file uncomment
    # this fp.write("New file created")
    # #send_ses_email("mnoguera@irsicaixa.es","Test","Started")
    # bashCommand = 'bash '+pathname+'/fetchAndUpload.sh '+myArg
    # print(bashCommand)
    # #process = subprocess.Popen(bashCommand.split(), stdout=subprocess.PIPE,stderr=subprocess.PIPE)
    # process = subprocess.Popen(bashCommand.split())
    # output, error = process.communicate()
    # my_file = Path("/tmp/"+myArg+"_completed.txt")
    #if my_file.is_file():
    #    my_file.unlink()
    # send_ses_email("mnoguera@irsicaixa.es","Test","Finished")

