#!/bin/bash

COMMON_SCRIPT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"
# shellcheck source=cicd/ci/common.sh
source "${COMMON_SCRIPT}"

compile() {

  echo "Rollback release"
  ${MVN_CMD} clean compile

}

next_version() {

  echo "Next version release"
  ${MVN_CMD} clean versions:set \
    -DnewVersion="${NEW_VERSION}"
}

deploy() {

  echo "Performing release"
  ${MVN_CMD} clean deploy -Preleases \
    -DgpgPassphrase="${GPG_PASSPHRASE}" \
    -DsonatypeUser="${SONATYPE_USER}" \
    -DsonatypePassword="${SONATYPE_PASSWORD}"

}

rollback() {

  echo "Rollback release"
  ${MVN_CMD} clean release:rollback

}

docs() {

  echo "Running docs"
  ${MVN_CMD} clean install -DskipTests -DskipITs -Pdocs

}

quality() {
  $(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/quality_gate.sh "${SONAR_HOST}" "${SONAR_LOGIN}" "${SONAR_BRANCH}"
}

full_build() {

  echo "Running full_build ${SONAR_BRANCH}"
  ${MVN_CMD} clean install sonar:sonar -U -P sonar \
    -DsonarOrganization="${SONAR_ORGANIZATION}" \
    -DsonarHost="${SONAR_HOST}" \
    -DsonarLogin="${SONAR_LOGIN}" \
    -DsonarBranch="${SONAR_BRANCH}"

  quality
}

no_ci_build() {

  echo "Skipping ITs, SonarScan likely this build is a local build"
  ${MVN_CMD} install -DskipITs
  echo ""
  echo "To run full_build and deploy set environments"
  echo "Common Vars: CI_SECURE_ENV_VARS"
  echo "To build: SONAR_ORGANIZATION, SONAR_HOST, SONAR_LOGIN"
  echo "To release: PULL_REQUEST, SONATYPE_USER, SONATYPE_PASSWORD"
  echo "To next_version: HAS_NEW_VERSION"
  echo "To build documentation: IS_DOCS"
  echo ""

}

# run 'mvn release:perform' if we can
if [ "${DEPLOY}" = true ]; then
  deploy
else
  if [ "${HAS_NEW_VERSION}" = true ]; then
    next_version
  else
    if [ "$IS_DOCS" ]; then
      docs
    else
      if [ "${RUN_ITS}" = true ]; then
        full_build
      else
        # fall back to running an install and skip the ITs and SonarScan
        if [ "${IS_COMPILE}" = true ]; then
          compile
        else
          # fall back to running an install and skip the ITs and SonarScan
          no_ci_build
        fi
      fi
    fi
  fi
fi
