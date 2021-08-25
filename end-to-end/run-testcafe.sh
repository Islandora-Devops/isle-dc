#!/bin/sh
testcafe chromium tests/admin/*.spec.js && \
testcafe chromium tests/ui/data-migrations.js && \
testcafe chromium tests/ui/data-media.js && \
testcafe --concurrency 2 chromium tests/ui/*.spec.js
