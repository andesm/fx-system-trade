#!/bin/bash -x

stack clean && stack build --profile && stack exec -- fx-exe backtest-latest +RTS -xc


