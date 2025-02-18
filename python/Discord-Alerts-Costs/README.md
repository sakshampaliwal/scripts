# AWS Cost Alert on Discord

## **1. Create a Discord Webhook**

1. Open Discord and go to the desired channel.
2. Click on **Edit Channel** (gear icon next to the channel name).
3. Navigate to **Integrations** > **Webhooks**.
4. Click **New Webhook** and name it accordingly.
5. Copy the Webhook URL and save it for later.

---

## **2. Create an IAM Role for Lambda**

1. Go to **AWS IAM Console** > **Roles** > **Create Role**.
2. Select **AWS Service** and choose **Lambda**.
3. Attach the policy: **AWS Cost Explorer Read-Only Access**.
4. Attach the following custom policy:

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "ce:GetCostAndUsage",
                "ce:GetCostForecast",
                "ce:GetDimensionValues",
                "ce:GetReservationCoverage",
                "ce:GetReservationUtilization",
                "ce:GetRightsizingRecommendation",
                "ce:GetSavingsPlansCoverage",
                "ce:GetSavingsPlansUtilization",
                "ce:GetSavingsPlansUtilizationDetails"
            ],
            "Resource": "*"
        }
    ]
}

```

1. Click **Next**, name the role, and create it.

---

## **3. Create the Lambda Function**

1. Go to **AWS Lambda Console** > **Create Function**.
2. Select **Author from Scratch**.
3. Enter **daily-aws-cost-to-discord** as the function name.
4. Choose **Python 3.10** as the runtime.
5. Assign the IAM Role created earlier.
6. Click **Create Function**.

---

## **4. Prepare and Upload the Lambda Code**

Create a **lambda_function.py** file containing the logic to fetch AWS costs and send them to Discord.

### **Steps to Create and Zip the Code**

### **For Linux/macOS:**

```
mkdir lambda_cost
cd lambda_cost
# Add your lambda_function.py file here
pip install requests -t .
zip -r lambda_function.zip .

```

### **For Windows:**

```powershell
# Create a folder and place your lambda_function.py inside
pip install requests -t .
Compress-Archive -Path * -DestinationPath lambda_function.zip

```

### **Upload to AWS Lambda**

1. Go to your **daily-aws-cost-to-discord** Lambda function.
2. Click **Upload from** and select the **lambda_function.zip**.
3. Save and deploy the function.

---

## **5. Create Event Scheduler for Daily Execution**

1. Go to **AWS EventBridge Console**.
2. Click on **Scheduler** > **Create Schedule**.
3. Set the schedule type to **Recurring** and configure it to run daily.
4. Choose **Lambda Function** as the target.
5. Select the **daily-aws-cost-to-discord** function.
6. Review and create the schedule.

If the scheduler requires permissions, you can allow it to create an IAM role automatically.

Now, AWS cost alerts will be sent daily to your Discord channel! 🎉