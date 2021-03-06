{-# LANGUAGE ExtendedDefaultRules #-}
{-# LANGUAGE OverloadedStrings    #-}

module FxMongodb
  ( setFxTradeData
  , updateFxTradeData
  , writeFxSettingData
  , readFxSettingData
  , readFxSettingDataLog
  , checkFxSettingData
  , readBacktestResult
  , writeBacktestResult
  ) where

import           Control.Exception.Extra
import           Control.Monad.Trans.Reader
import qualified Data.Map                   as M
import qualified Data.Text                  as T
import           Database.MongoDB
import           Debug.Trace
import qualified FxSettingData              as Fsd
import qualified FxTradeData                as Ftd
import qualified GlobalSettingData          as Gsd

setFxTradeData :: String-> Ftd.FxTradeData -> IO ()
setFxTradeData coName td = do
  pipe <- retry 100 $ connect (readHostPort $ Gsd.dbHost Gsd.gsd)
  _ <- access pipe master "fx" $ setFxTradeDataToDB (T.pack coName) td
  close pipe

updateFxTradeData :: String -> Ftd.FxTradeData -> IO Ftd.FxTradeData
updateFxTradeData coName td = do
  pipe <- retry 100 $ connect (readHostPort $ Gsd.dbHost Gsd.gsd)
  r <- access pipe master "fx" $ getDataFromDB (T.pack coName)
  close pipe
  if null r
    then return td
    else head <$> mapM (\x -> return $ td { Ftd.chart         = read . typed $ valueAt "chart"         x
                                          , Ftd.tradeRate     = read . typed $ valueAt "tradeRate"     x
                                          , Ftd.trSuccess     = read . typed $ valueAt "trSuccess"     x
                                          , Ftd.trFail        = read . typed $ valueAt "trFail"        x
                                          , Ftd.profit        = read . typed $ valueAt "profit"        x}) r

readFxSettingData :: IO Fsd.FxSettingData
readFxSettingData = do
  pipe <- retry 100 $ connect (readHostPort $ Gsd.dbHost Gsd.gsd)
  r <- access pipe master "fx" $ getDataFromDB  "fxsetting_log"
  close pipe
  if null r
    then return Fsd.initFxSettingData
    else do fs  <- head <$> mapM (\x -> return (read . typed $ valueAt "fs" x)) r
            fsl <- head <$> mapM (\x -> return (read . typed $ valueAt "fsl" x)) r
            return $ Fsd.setFxSettingData fs fsl

readFxSettingDataLog :: Fsd.FxSettingData -> IO Fsd.FxSettingData
readFxSettingDataLog fsd = do
  pipe <- retry 100 $ connect (readHostPort $ Gsd.dbHost Gsd.gsd)
  r <- access pipe master "fx" $ getDataFromDB  "fxsetting_log"
  close pipe
  if null r
    then return Fsd.initFxSettingData
    else do fsl <- head <$> mapM (\x -> return (read . typed $ valueAt "fsl" x)) r
            return $ Fsd.setFxSettingDataLog fsd fsl

checkFxSettingData :: IO Bool
checkFxSettingData = do
  pipe <- retry 100 $ connect (readHostPort $ Gsd.dbHost Gsd.gsd)
  r <- access pipe master "fx" $ getDataFromDB "fxsetting_log"
  close pipe
  if null r
    then return True
    else return False

writeFxSettingData :: Fsd.FxSettingData -> IO Fsd.FxSettingData
writeFxSettingData fsd = do
  pipe <- retry 100 $ connect (readHostPort $ Gsd.dbHost Gsd.gsd)
  _ <- access pipe master "fx" $ setFxSettingToDB (Fsd.fxSetting fsd) (Fsd.fxSettingLog fsd)
  close pipe
  return fsd

readBacktestResult :: String -> IO (Int, Int)
readBacktestResult name = do
  pipe <- retry 100 $ connect (readHostPort $ Gsd.dbHost Gsd.gsd)
  r <- access pipe master "fx" . getDataFromDB $ T.pack ("result_" ++ name )
  close pipe
  if null r
    then return (0, 0)
    else do s <- head <$> mapM (\x -> return (read . typed $ valueAt "success" x)) r
            f <- head <$> mapM (\x -> return (read . typed $ valueAt "fail"    x)) r
            return (s , f)

writeBacktestResult :: String -> Int -> Int -> IO ()
writeBacktestResult name s f = do
  pipe <- retry 100 $ connect (readHostPort $ Gsd.dbHost Gsd.gsd)
  _ <- access pipe master "fx" $ setBacktestResultToDB ("result_" ++ name ) s f
  close pipe
  return ()

getDataFromDB :: T.Text -> ReaderT MongoContext IO [Document]
getDataFromDB coName =
  rest =<< find (select [] coName)

setFxTradeDataToDB :: T.Text -> Ftd.FxTradeData -> Action IO ()
setFxTradeDataToDB coName td =
  upsert (select [] coName) [ "chart"          =: show (Ftd.chart         td)
                            , "tradeRate"      =: show (Ftd.tradeRate     td)
                            , "trSuccess"      =: show (Ftd.trSuccess     td)
                            , "trFail"         =: show (Ftd.trFail        td)
                            , "profit"         =: show (Ftd.profit        td)
                            ]

setFxSettingToDB :: Fsd.FxSetting -> M.Map Fsd.FxSetting (Double, Int) -> Action IO ()
setFxSettingToDB fs fsl =
  upsert (select [] "fxsetting_log" ) [ "fs"  =: show fs
                                      , "fsl" =: show fsl
                                      ]

setBacktestResultToDB :: String -> Int -> Int -> Action IO ()
setBacktestResultToDB name s f =
  upsert (select [] (T.pack name)) [ "success" =: show s
                                   , "fail"    =: show f
                                   ]


