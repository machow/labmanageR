labmanageR
==========

Slacking you the latest and greatest changes from your Open Science Framework projects.


Installing
------------

```R
# Also be sure to install these packages
remotes::install_github("CenterForOpenScience/osfr")
remotes::install_github("hrbrmstr/slackr")


# install labmanageR from github
remotes::install_github("machow/labmanageR")

```

Check for a user's OSF updates
--------------------------------

The code below will print out a table of changes made after January 1st.
(The user ID being used here is mine :).

```R
library(labmanageR)

osf_report_modified("aswnc", after_date = "2019-01-01")
```


Slackbot
--------

For posting changes to slack, you can use the `osf_report_modified_slack` command with the same options.
You'll also need to set up an incoming webhook on slack, so that the slackr package knows where to send your updates.

See

* [slack docs on incoming webhooks](https://api.slack.com/incoming-webhooks)
* [slackr setup docs](https://github.com/hrbrmstr/slackr#setup)


```R
osf_report_modified_slack("aswnc", after_date = "2016-01-01", type = "user")
```



Setting your slackbot to run in the background
----------------------------------------------


