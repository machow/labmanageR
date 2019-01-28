require("labmanageR")
require("lubridate")

args = commandArgs(trailing = TRUE)

print(args)

after_date <- now("UTC") - hours(args[2])

to_pass = list(
    id = args[1],
    after_date,
    type = args[3]
    )

print(to_pass)

print("WHAT IS HAPPENING")

if (length(args) > 3) {
    to_pass$incoming_webhook_url = args[4]
}

do.call(labmanageR::osf_report_modified_slack, to_pass)
