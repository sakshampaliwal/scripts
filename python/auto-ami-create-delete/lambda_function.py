import boto3
from datetime import datetime, timedelta

today = datetime.utcnow().strftime('%Y-%m-%d')
five_days_ago = (datetime.utcnow() - timedelta(days=5)).strftime('%Y-%m-%d')

print(f"Today: {today}")
print(f"5 days ago: {five_days_ago}")

INSTANCE_SETTINGS = [
    {"id": "i-00ed717a723f7d148", "name": "Karma Prod", "region": "ap-south-1"},
    {"id": "i-02e14442889becc6c", "name": "Karma Prod B2C", "region": "ap-south-1"},
]

def create_ami(ec2_client, instance):
    """Create AMI for the given instance"""
    ami_name = f"auto-ami-{instance['name']}-{today}"
    try:
        response = ec2_client.create_image(
            InstanceId=instance['id'],
            Name=ami_name,
            Description="Created from Lambda",
            NoReboot=True
        )
        print(f"AMI Created: {response['ImageId']} for {instance['name']}")
    except Exception as e:
        print(f"Error creating AMI for {instance['name']}: {e}")

def delete_old_ami(ec2_client, instance):
    """Find and delete old AMI along with its snapshot"""
    old_ami_name = f"auto-ami-{instance['name']}-{five_days_ago}"
    print(f"Searching for old AMI: {old_ami_name}")
    
    try:
        images = ec2_client.describe_images(
            Filters=[{"Name": "name", "Values": [old_ami_name]}],
            Owners=["self"]
        )["Images"]

        if not images:
            print(f"No old AMI found for {instance['name']}")
            return
        
        old_ami_id = images[0]["ImageId"]
        snapshot_id = images[0]["BlockDeviceMappings"][0]["Ebs"]["SnapshotId"]

        ec2_client.deregister_image(ImageId=old_ami_id)
        print(f"AMI {old_ami_id} deregistered for {instance['name']}")

        ec2_client.delete_snapshot(SnapshotId=snapshot_id)
        print(f"Snapshot {snapshot_id} deleted for {instance['name']}")

    except Exception as e:
        print(f"Error deleting old AMI for {instance['name']}: {e}")

def lambda_handler(event, context):
    """Lambda function entry point"""
    for instance in INSTANCE_SETTINGS:
        ec2_client = boto3.client("ec2", region_name=instance["region"])
        create_ami(ec2_client, instance)
        delete_old_ami(ec2_client, instance)
