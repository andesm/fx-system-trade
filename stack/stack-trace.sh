#!/bin/bash -x

stack clean && stack build --profile && stack exec -- fx-exe backtest +RTS -xc


