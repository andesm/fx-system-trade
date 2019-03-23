module GaFx
  ( backTest
  , trade
  , debug
  ) where

import           Control.Concurrent
import           Control.Concurrent.Async
import           Control.Monad.Random
import           Control.DeepSeq
import qualified Data.Map                 as M
import           Data.Time
import           Data.Time.Clock.POSIX
import           Debug.Trace
import qualified FxChartData              as Fcd
import qualified FxMongodb                as Fm
import qualified FxOandaAPI               as Foa
import qualified FxPrint                  as Fp
import qualified FxSetting                as Fs
import qualified FxSettingData            as Fsd
import qualified FxTrade                  as Ft
import qualified FxTradeData              as Ftd
import qualified FxTweet                  as Ftw
import qualified Ga
import qualified GlobalSettingData        as Gsd

instance Ga.Ga Fsd.FxSettingData where
  copy              = Fs.copyFxSettingData
  mutation          = Fs.mutationFxSettingData
  crossover         = Fs.crossoverFxSettingData
  createInitialData = Fs.createInitialGaData
  learningEvaluate  = Ft.gaLearningEvaluate
  getGaLoopMax      = Fsd.getLearningTestTimes
  plusGaLoopMax     = Fsd.plusLearningTestTimes
  reset             = Fs.resetFxSettingData
  setHash           = Fs.setHashFxSettingData

debug :: IO ()
debug = do
  fsd <- Fm.readFxSettingData "backtest"
  traceShow(M.elems $ Fsd.fxSettingLog fsd) $ return ()
  return ()

backTest :: String -> Bool -> Bool -> IO ()
backTest coName latest retry = do
  fsd <- Fm.readFxSettingData "backtest"
  (s, f) <- Fm.readResult coName
  let td  = Ft.initFxTradeData Ftd.Backtest
      ltt = Fs.getLearningTestTime fsd
      lt  = Fs.getLearningTime fsd
      p = Fs.getPrepareTimeAll fsd + lt + ltt * Gsd.learningTestCount Gsd.gsd
  endN <- Fcd.no <$> Fm.getOneChart Fm.getEndChartFromDB
  sn <- if latest
        then return (endN - (p + ltt * Gsd.learningTestCount Gsd.gsd + Gsd.backtestLatestTime Gsd.gsd))
        else Fcd.no <$> Fm.getOneChart Fm.getStartChartFromDB
  startN <- getRandomR(sn, sn + ltt * 2)                  
  let n = startN + p
  (fs, fsd') <- backTestLoop retry False n endN td fsd
  (s', f') <- if fs
              then do Fp.printBackTestResult "=================================" (s + 1) f fsd'
                      return (s + 1, f)
              else do Fp.printBackTestResult "---------------------------------" s (f + 1) fsd'
                      return (s, f + 1)
  Fm.writeResult coName s' f'
  backTest coName latest retry

trade :: Ftd.FxEnvironment -> String -> IO ()
trade environment coName = do
  c <- Fm.getOneChart Fm.getEndChartFromDB
  td <- Foa.updateFxTradeData =<< (Fm.updateFxTradeData coName $ (Ft.initFxTradeData environment) { Ftd.chart = c })
  Fp.printProgressFxTradeData td c
  tradeWeeklyLoop td coName

learningLoop :: Int ->
                Int ->
                [Fcd.FxChartData] -> 
                Fsd.FxSettingData ->
                IO (Int, Bool, Ftd.FxTradeData, [Ftd.FxTradeData], Fsd.FxSettingData)
learningLoop c n xcd fsd = do
  let lt = Fs.getLearningTime fsd
      cl = Fcd.getChartListBack 0 (Fs.getPrepareTimeAll fsd + lt) xcd
  (p', tdl, tdlt, fsd') <-
    (maximum . map (\x -> let lt'  = Fs.getLearningTime     x
                              ltt' = Fs.getLearningTestTime x
                              cl'  = Fcd.getChartListBack 0 (Fs.getPrepareTimeAll x + lt') xcd
                              ce'  = map (\y -> Fcd.getChartListBack (ltt' * y + lt') (Fs.getPrepareTimeAll x + ltt') xcd)
                                     [0..Gsd.learningTestCount Gsd.gsd - 1]
                              tdlt = map (\y -> Ft.learning $ Fsd.nextFxSettingData ltt' y x) ce'
                              tdl  = Ft.learning $ Fsd.nextFxSettingData lt' cl' x
                              p    = Ftd.getEvaluationValue tdl + Ftd.getEvaluationValueList tdlt
                          in (p, tdl, tdlt, x)) . (fsd:) . Ga.getGaDataList) <$>
    (Ga.learning . Ga.learningData $ Fsd.nextFxSettingData lt cl fsd)
  -- Fp.printLearningFxTradeData p' 0 fsd' tdl tdlt 0 (Ft.evaluationOk tdl tdlt) (fsd' == fsd)
  if Ft.evaluationOk tdl tdlt
    then return (0, True, tdl, tdlt, fsd')
    else if (Fsd.learningTestTimes . Fsd.learningSetting $ Fsd.fxSetting fsd') < fromIntegral c || fsd' == fsd
         then return (0, False, tdl, tdlt, Fsd.plusLearningTestTimes fsd')
         else learningLoop (c + 1) n xcd fsd' 

learning :: Int ->
            Fsd.FxSettingData ->
            IO (Int, Bool, Ftd.FxTradeData, [Ftd.FxTradeData], Fsd.FxSettingData)
learning n fsd = do
  let fsl  = M.insert (Fsd.fxSetting fsd) (1, 1) $ Fsd.fxSettingLog fsd
      lt  = maximum . M.elems $ M.mapWithKey (\x (_, _) -> Fs.getLearningTime     fsd { Fsd.fxSetting = x }) fsl
      ltt = maximum . M.elems $ M.mapWithKey (\x (_, _) -> Fs.getLearningTestTime fsd { Fsd.fxSetting = x }) fsl
      pre = maximum . M.elems $ M.mapWithKey (\x (_, _) -> Fs.getPrepareTimeAll   fsd { Fsd.fxSetting = x }) fsl
  xcd <- Fm.getChartListBack n ((pre + lt + ltt * Gsd.learningTestCount Gsd.gsd) * 2) 0
  let tdlts = M.elems .
              M.filter (\(y, _, _, _) -> y) $
              M.mapWithKey (\y ( p, c) -> let fsd' = fsd { Fsd.fxSetting = y }
                                              lt'  = Fs.getLearningTime     fsd'
                                              ltt' = Fs.getLearningTestTime fsd'
                                              cl   = Fcd.getChartListBack 0 (Fs.getPrepareTimeAll fsd' + lt') xcd
                                              ce   =  map (\x -> Fcd.getChartListBack (ltt' * x + lt')
                                                            (Fs.getPrepareTimeAll fsd' + ltt') xcd)
                                                      [0..Gsd.learningTestCount Gsd.gsd - 1]
                                              tdlt = map (\x-> Ft.learning $ Fsd.nextFxSettingData ltt' x fsd') ce
                                              tdl  = Ft.learning $ Fsd.nextFxSettingData lt' cl fsd'
                                              p'   = (Ftd.getEvaluationValue tdl + Ftd.getEvaluationValueList tdlt) *
                                                     (p / fromIntegral c)
                                          in (Ft.evaluationOk tdl tdlt, tdl, tdlt, fsd')) fsl
      (_, tdl', tdlt', fsd'') = maximum tdlts
  if not $ null tdlts
    then return (length tdlts, True, tdl', tdlt',  fsd'')
    else learningLoop 0 n xcd fsd 

tradeLearning :: IO (Int, Fsd.FxSettingData)
tradeLearning = do
  fsd <- Fm.readFxSettingData "backtest"
  e <- Fm.getOneChart Fm.getEndChartFromDB 
  (plsf, lsf, tdl, tdlt, fsd') <- learning (Fcd.no e) fsd
  -- Fp.printLearningFxTradeData 0 (Fcd.no e) fsd' tdl tdlt plsf lsf
  return (Fcd.no e, fsd')

backTestLoop :: Bool ->
                Bool ->
                Int ->
                Int ->
                Ftd.FxTradeData ->
                Fsd.FxSettingData ->
                IO (Bool, Fsd.FxSettingData)
backTestLoop retry lf n endN td fsd = do
  (plsf, lok, tdl, tdlt, fsd1) <- if (not $ M.member (Fsd.fxSetting fsd) (Fsd.fxSettingLog fsd)) || Ftd.side td == Ftd.None || lf
                                  then learning n fsd
                                  else return (0, False, Ftd.initFxTradeDataCommon, [Ftd.initFxTradeDataCommon], fsd)
  let lt  = Fs.getLearningTime     fsd1
      ltt = Fs.getLearningTestTime fsd1
  (fsd2, tdt) <- Ft.backTest (lt + ltt * Gsd.learningTestCount Gsd.gsd) td fsd1
                 <$> ((++) <$>
                       Fm.getChartListBack    (n - 1) (Fs.getPrepareTimeAll fsd1) 0 <*>
                       Fm.getChartListForward n       (lt + ltt * Gsd.learningTestCount Gsd.gsd) 0)
  if Ftd.realizedPL tdt < Ftd.realizedPL td && retry && not lok && Ftd.side td == Ftd.None
    then do Fp.printTestProgress fsd1 fsd td tdt tdl tdlt plsf lok True
            backTestLoop retry True n endN td =<< (Ga.getHeadGaData <$> (Fs.resetFxSettingData $ Ga.learningData fsd))
    else do fsd3 <- Fm.writeFxSettingData "backtest"
                    <$> Fs.updateFxSettingLog plsf ((Ftd.realizedPL tdt - Ftd.realizedPL td) / (fromIntegral $ (lt + ltt * Gsd.learningTestCount Gsd.gsd))) fsd2
                    =<< Fm.readFxSettingData "backtest"
            Fp.printTestProgress fsd1 fsd td tdt tdl tdlt plsf lok False
            let n' = Fcd.no (Ftd.chart tdt) + 1
            if endN <= n' || Ftd.realizedPL tdt < Gsd.initalProperty Gsd.gsd / Gsd.quantityRate Gsd.gsd
              then return (Gsd.initalProperty Gsd.gsd < Ftd.realizedPL tdt, fsd2)
              else backTestLoop retry (Ftd.realizedPL td < Ftd.realizedPL tdt) n' endN tdt fsd3

tradeEvaluate :: Ftd.FxTradeData ->
                 Fsd.FxSettingData ->
                 String ->
                 [Fcd.FxChartData] ->
                 IO (Fsd.FxSettingData, Ftd.FxTradeData)
tradeEvaluate td fsd coName xcd = do
  let (open, close, fsd1, td1) = Ft.trade td fsd xcd
  td3 <- if close /= Ftd.None
         then do td2 <- Foa.close td1
                 Fm.setFxTradeData coName td2
                 Fp.printTradeResult open close td td2 0
                 return td2
         else return td1
  td5 <- if open /= Ftd.None
         then do (units, td4) <- Foa.open td3 open
                 Fm.setFxTradeData coName td4
                 Fp.printTradeResult open close td td4 units
                 return td4
         else return td3
  return (fsd1, td5)

waitTrade :: IO ()
waitTrade =
  waitTradeLoop =<< Fm.getOneChart Fm.getEndChartFromDB

waitTradeLoop :: Fcd.FxChartData -> IO ()
waitTradeLoop p = do
  e <- Fm.getOneChart Fm.getEndChartFromDB
  if e /= p
    then return ()
    else do threadDelay (10 * 1000 * 1000)
            waitTradeLoop e

tradeWeeklyLoop :: Ftd.FxTradeData ->
                   String ->
                   IO ()
tradeWeeklyLoop td coName = do
  waitTrade
  (pl, fsd') <- tradeLearning
  e <- Foa.getNowPrices td
  td' <- tradeLoop e pl 0 td fsd' coName
  tdw <- Fm.updateFxTradeData (coName ++ "_weekly") td
  -- Ftw.tweetWeek tdw td'
  Fm.setFxTradeData (coName ++ "_weekly") td'
  tradeWeeklyLoop td' coName

tradeLoop :: Fcd.FxChartData ->
             Int ->
             Int ->
             Ftd.FxTradeData ->
             Fsd.FxSettingData ->            
             String ->
             IO Ftd.FxTradeData
tradeLoop p pl sleep td fsd coName = do
  t <- getCurrentTime
  threadDelay ((15 - (truncate (utcTimeToPOSIXSeconds t) `mod` 15)) * 1000 * 1000)
  let lt  = Fs.getLearningTime     fsd
      ltt = Fs.getLearningTestTime fsd
  e <- Foa.getNowPrices td
  (pl', fsd1) <- if Ftd.side td == Ftd.None && lt + ltt * Gsd.learningTestCount Gsd.gsd < Fcd.no e - pl
                 then tradeLearning
                 else return (pl, fsd)
  (sleep', td2, fsd3) <- if (Fcd.close e) /= (Fcd.close p)
                         then do (fsd2, td1) <- tradeEvaluate td fsd1 coName =<<
                                                ((++) <$> Fm.getChartListBack (Fcd.no e - 1) (Fs.getPrepareTimeAll fsd1) 0 <*> pure [e])
                                 -- Fp.printProgressFxTradeData td1 e                                 
                                 return (0, td1, fsd2)
                         else return (sleep + 1, td, fsd1)
  if 240 < sleep'
    then do return td2
    else tradeLoop e pl' sleep' td2 fsd3 coName

