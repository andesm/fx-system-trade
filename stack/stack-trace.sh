#!/bin/bash -x

stack clean && stack build --profile && stack exec -- fx-exe trade-practice +RTS -xc


