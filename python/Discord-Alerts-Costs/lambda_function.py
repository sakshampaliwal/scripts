import json
import boto3
import requests
from datetime import datetime, timedelta

# Initialize AWS Cost Explorer client
client = boto3.client("ce")

# Discord Webhook URL
DISCORD_WEBHOOK_URL = "https://discord.com/api/webhooks/1341357113661984868/Pf-g4SHsWg9PHzVK6qm6oQjnz2ImAFX2Ax5_CBMDd2EY_exaJ8TV8xN3RZFlIvTwLxu3"

def get_aws_cost():
    """Fetch AWS cost for the last 7 days"""
    end_date = datetime.utcnow().date()
    start_date = end_date - timedelta(days=7)

    response = client.get_cost_and_usage(
        TimePeriod={"Start": start_date.strftime("%Y-%m-%d"), "End": end_date.strftime("%Y-%m-%d")},
        Granularity="DAILY",
        Metrics=["UnblendedCost"]
    )

    total_cost = 0.0
    daily_costs = []
    currency = "USD"

    for day in response["ResultsByTime"]:
        date = day["TimePeriod"]["Start"]
        cost = float(day["Total"]["UnblendedCost"].get("Amount", 0.0))
        currency = day["Total"]["UnblendedCost"].get("Unit", "USD")
        total_cost += cost
        daily_costs.append(f"🗓 `{date}` → **${cost:.2f}** {currency}")

    daily_breakdown = "\n\n".join(daily_costs)  # Adding two-line gaps
    return total_cost, currency, daily_breakdown, start_date, end_date - timedelta(days=1)

def get_forecasted_cost():
    """Fetch AWS cost forecast for the current month"""
    today = datetime.utcnow().date()
    start_of_month = today.replace(day=1)
    end_of_month = (today.replace(day=28) + timedelta(days=4)).replace(day=1) - timedelta(days=1)  # Last day of month

    try:
        response = client.get_cost_forecast(
            TimePeriod={"Start": today.strftime("%Y-%m-%d"), "End": end_of_month.strftime("%Y-%m-%d")},
            Granularity="MONTHLY",
            Metric="UNBLENDED_COST"
        )
        forecasted_cost = float(response["Total"]["Amount"])
        currency = response["Total"]["Unit"]
    except Exception:
        forecasted_cost = 0.0
        currency = "USD"

    return forecasted_cost, currency, start_of_month, end_of_month

def send_to_discord(total_cost, currency, daily_breakdown, start_date, end_date, forecasted_cost, forecast_start, forecast_end):
    """Send cost report and forecast to Discord"""
    embed_data = {
        "embeds": [
            {
                "title": "💰 AWS Cost Report\n",
                "description": f"**Billing Period:**`{start_date} → {end_date}`",
                "color": 15844367,  # Yellow
                "fields": [
                    {"name": "🎗️**Daily Breakdown**🎗️\n\n", "value": f"{daily_breakdown}\n\n**━━━━━━━━━━━━━━━━━━**", "inline": False},
                    {"name": "📈 **Forecasted Cost (This Month)\n\n**", "value": f"Estimated: **${forecasted_cost:.2f}** {currency}\n\n📆 Billing Period: `{forecast_start} → {forecast_end}`\n\n**━━━━━━━━━━━━━━━━━━**", "inline": False}
                ],
                "footer": {"text": "AWS Cost Report • Powered by Devkraft"},
                "timestamp": datetime.utcnow().isoformat(),
            }
        ]
    }

    requests.post(DISCORD_WEBHOOK_URL, json=embed_data)

def lambda_handler(event, context):
    total_cost, currency, daily_breakdown, start_date, end_date = get_aws_cost()
    forecasted_cost, forecast_currency, forecast_start, forecast_end = get_forecasted_cost()

    send_to_discord(total_cost, currency, daily_breakdown, start_date, end_date, forecasted_cost, forecast_start, forecast_end)
    
    return {"statusCode": 200, "body": json.dumps("AWS Cost Report sent to Discord!")}
