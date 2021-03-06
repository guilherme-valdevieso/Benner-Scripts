#!/bin/bash

branchPrefix="remotes/origin/"
RELEASE_BRANCH=""
RELEASE_NUMBER=""

CONFIGURATION="Loc.SqlS.Release"
CONECTA_DIR="/e/Compart/Conecta/Conecta"
nextStep="1"

while getopts 'c:d:n:b:' flag; do
  case "${flag}" in
    b) RELEASE_BRANCH="${OPTARG}" ;;
    c) CONFIGURATION="${OPTARG}" ;;
    d) CONECTA_DIR="${OPTARG}" ;;
    n) nextStep="${OPTARG}" ;;
    *) error "Unexpected option ${flag}" ;;
  esac
done

function setReleaseBranch() {
    if [[ -z "$RELEASE_BRANCH" ]]; then
        RELEASE_BRANCH=$(git branch -a | grep origin/release)
        if [[ -z "$RELEASE_BRANCH" || "$RELEASE_BRANCH" == *$'\n'* ]]; then
            echo "Multiple release branches found"
            exit 1
        fi

        RELEASE_BRANCH=${RELEASE_BRANCH//$branchPrefix/}
        RELEASE_BRANCH=$(echo "$RELEASE_BRANCH" | xargs)
    fi

    RELEASE_NUMBER=$(echo $RELEASE_BRANCH | grep -oP "\d+$")
    RELEASE_NUMBER=$((RELEASE_NUMBER+1))
}

function exitIfLastHasError() {
    if [[ $? -ne 0 ]]; then
        iexit "$1"
    fi
}

function iexit() {
    echo "Exit with code $1"
    echo "Re-run passing $1 to continue..."
    popd
    exit $1
}

function buildInternal() {
    build.sh -f "Conecta-coverage.sln" -p "//p:Configuration=$CONFIGURATION //p:OutputPath=bin\\$CONFIGURATION"
    exitIfLastHasError "$1"
}

function runTestsInternal() {
    runtestsfromconecta.sh -d "." -c "$CONFIGURATION"
    exitIfLastHasError "$1"
}

function updateMaster() {
    git checkout master
    git reset --hard origin/master
    git tag $(echo master-`date +%Y-%m-%d`)
    git pull origin $RELEASE_BRANCH
    exitIfLastHasError "$1"
    git tag $(echo ${RELEASE_BRANCH#*/})
}

function updateDevelop() {
    git checkout develop
    git reset --hard origin/develop
    git pull origin $RELEASE_BRANCH
    exitIfLastHasError "$1"
}

function createNewReleaseBranch() {
    git checkout develop
    git checkout -b "release/Sprint$RELEASE_NUMBER"
    git push -u
}

function start() {
    pushd "$CONECTA_DIR"
    git fetch --prune

    setReleaseBranch

    if [[ $nextStep -le 1 ]]; then
        updateMaster 1
    fi

    if [[ $nextStep -le 2 ]]; then
        updateDevelop 2
    fi

    if [[ $nextStep -le 3 ]]; then
        git checkout master
        buildInternal 3
    fi
    if [[ $nextStep -le 4 ]]; then
        git checkout master
        runTestsInternal 4
    fi
    if [[ $nextStep -le 5 ]]; then
        git push origin master --no-verify
    fi

    if [[ $nextStep -le 6 ]]; then
        git checkout develop
        buildInternal 6
    fi
    if [[ $nextStep -le 7 ]]; then
        git checkout develop
        runTestsInternal 7
    fi
    if [[ $nextStep -le 8 ]]; then
        git checkout develop
        git push origin develop --no-verify
    fi
    if [[ $nextStep -le 9 ]]; then
        createNewReleaseBranch
    fi

    popd
}

start