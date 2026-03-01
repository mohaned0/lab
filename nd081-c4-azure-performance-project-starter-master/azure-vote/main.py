from flask import Flask, request, render_template
import os
import redis
import socket
import logging

# App Insights (OpenCensus)
from opencensus.ext.azure.log_exporter import AzureEventHandler
from opencensus.ext.azure import metrics_exporter
from opencensus.ext.azure.trace_exporter import AzureExporter
from opencensus.trace.samplers import ProbabilitySampler
from opencensus.trace.tracer import Tracer
from opencensus.ext.flask.flask_middleware import FlaskMiddleware


# -------------------------
# App configuration
# -------------------------
app = Flask(__name__)
app.config.from_pyfile('config_file.cfg')

button1 = os.environ.get("VOTE1VALUE") or app.config['VOTE1VALUE']
button2 = os.environ.get("VOTE2VALUE") or app.config['VOTE2VALUE']
title = os.environ.get("TITLE") or app.config['TITLE']

if app.config.get('SHOWHOST') == "true":
    title = socket.gethostname()


# -------------------------
# Application Insights setup
# -------------------------
CONNECTION_STRING = "InstrumentationKey=339ac93f-2eec-4039-91bb-4d29b7fc4036;IngestionEndpoint=https://eastus-8.in.applicationinsights.azure.com/;LiveEndpoint=https://eastus.livediagnostics.monitor.azure.com/;ApplicationId=9c61d2ac-21ba-436b-a6c7-856ec6017c42"

# Logging -> Events/Traces tables
logger = logging.getLogger("azurevote")
logger.setLevel(logging.INFO)
logger.addHandler(AzureEventHandler(connection_string=CONNECTION_STRING))

# Metrics (standard metrics)
metrics_exporter.new_metrics_exporter(
    enable_standard_metrics=True,
    connection_string=CONNECTION_STRING
)

# Tracing
tracer = Tracer(
    exporter=AzureExporter(connection_string=CONNECTION_STRING),
    sampler=ProbabilitySampler(1.0),
)

# Requests telemetry (auto-collect HTTP requests)
middleware = FlaskMiddleware(
    app,
    exporter=AzureExporter(connection_string=CONNECTION_STRING),
    sampler=ProbabilitySampler(1.0),
)


# -------------------------
# Redis (VMSS = local Redis)
# -------------------------
r = redis.Redis(host="localhost", port=6379)

# Init Redis keys
if not r.get(button1):
    r.set(button1, 0)
if not r.get(button2):
    r.set(button2, 0)


@app.route('/', methods=['GET', 'POST'])
def index():
    if request.method == 'GET':
        vote1 = r.get(button1).decode('utf-8')
        vote2 = r.get(button2).decode('utf-8')
        return render_template(
            "index.html",
            value1=int(vote1),
            value2=int(vote2),
            button1=button1,
            button2=button2,
            title=title
        )

    # POST
    if request.form['vote'] == 'reset':
        r.set(button1, 0)
        r.set(button2, 0)
    else:
        vote = request.form['vote']  # "Cats" or "Dogs"
        r.incr(vote, 1)

        # Custom event telemetry (visible in Logs -> traces table)
        properties = {'custom_dimensions': {'vote': vote}}
        logger.info(f"custom_event=vote_{vote.lower()}", extra=properties)

    vote1 = r.get(button1).decode('utf-8')
    vote2 = r.get(button2).decode('utf-8')
    return render_template(
        "index.html",
        value1=int(vote1),
        value2=int(vote2),
        button1=button1,
        button2=button2,
        title=title
    )


if __name__ == "__main__":
    app.run(host="0.0.0.0", threaded=True, debug=True)