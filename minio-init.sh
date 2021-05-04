#! /bin/sh
/usr/bin/mc config host add local http://minio:9000 ${DRUPAL_DEFAULT_S3_ACCESS_KEY} ${DRUPAL_DEFAULT_S3_SECRET_KEY};
/usr/bin/mc mb local/${DRUPAL_DEFAULT_S3_BUCKET};
/usr/bin/mc policy set download local/${DRUPAL_DEFAULT_S3_BUCKET};
