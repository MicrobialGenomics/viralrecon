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
    MaxNumberOfMessages=1,
    MessageAttributeNames=[
        'All'
    ],
    VisibilityTimeout=0,
    WaitTimeSeconds=0
)
print(response)
message = response['Messages'][0]
receipt_handle = message['ReceiptHandle']
myArg=(message['Body'])
print(myArg)
print(f"Number of messages received: {len(response.get('Messages', []))}")
#print('Received message: %s' % message)


### Taken from EntheraSeq Repo
def send_ses_email(mailAddress,projectName,state):
    ses_client = boto3.client('ses')
    # Replace sender@example.com with your "From" address.
    # This address must be verified with Amazon SES.
    SENDER = "CovidSeq Automated <mnoguera@irsicaixa.es>"

    # Replace recipient@example.com with a "To" address. If your account 
    # is still in the sandbox, this address must be verified.
    RECIPIENT = mailAddress

    # Specify a configuration set. If you do not want to use a configuration
    # set, comment the following variable, and the 
    # ConfigurationSetName=CONFIGURATION_SET argument below.
    #CONFIGURATION_SET = "ConfigSet"

    # If necessary, replace us-west-2 with the AWS Region you're using for Amazon SES.

    # The subject line for the email.
    SUBJECT = "CovidSeq Analysis event registered"

    # The email body for recipients with non-HTML email clients.
    BODY_TEXT = "CovidSeq Analysis has changed\n\n "
                 
                
    # The HTML body of the email.
    BODY_HTML = """<html>
    <head></head>
    <body>
    <h3> CovidSeq Analysis has started </h3>
    <p> We get in touch with you because the analysis project named {} has just changed state to {}.</p>
    <br>
    <p> Sincerely,</p>
    <p> The Enthera Team</p>
    </body>
    </html>
    """.format(projectName,state)            

    # The character encoding for the email.
    CHARSET = "UTF-8"

    # Create a new SES resource and specify a region.
    

    # Try to send the email.
    try:
        #Provide the contents of the email.
        response = ses_client.send_email(
            Destination={
                'ToAddresses': [
                    RECIPIENT,
                ],
            },
            Message={
                'Body': {
                    'Html': {
                        'Charset': CHARSET,
                        'Data': BODY_HTML,
                    },
                    'Text': {
                        'Charset': CHARSET,
                        'Data': BODY_TEXT,
                    },
                },
                'Subject': {
                    'Charset': CHARSET,
                    'Data': SUBJECT,
                },
            },
            Source=SENDER,
            # If you are not using a configuration set, comment or delete the
            # following line
            #ConfigurationSetName=CONFIGURATION_SET,
        )
    # Display an error if something goes wrong.	
    except ClientError as e:
        print(e.response['Error']['Message'])
    else:
        print("Email sent! Message ID:"),
        print(response['MessageId'])



#send_ses_email("mnoguera@irsicaixa.es","Test","Started")
bashCommand = 'bash '+pathname+'/fetchAndUpload.sh '+myArg
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

send_ses_email("mnoguera@irsicaixa.es","Test","Finished")

