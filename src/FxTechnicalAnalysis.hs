module FxTechnicalAnalysis
  ( makeFxTechnicalAnalysisDataList
  , makeValidLeafDataMapInc
  , makeValidLeafDataMapDec
  , calcFxalgorithmListCount
  , updateAlgorithmListCount
  , checkAlgoSetting
  , getLearningTestTime
  , getPrepareTimeAll
  , getHoldTime
  , createRandomFxAlMaSetting
  , createRandomFxAlgorithmSetting
  ) where

import           Control.Monad
import           Control.Monad.Random    as R
import           Data.List
import qualified Data.Map                as M
import           Debug.Trace
import qualified FxChartData             as Fcd
import qualified FxSettingData           as Fsd
import qualified FxTechnicalAnalysisData as Fad
import qualified GlobalSettingData       as Gsd
import qualified Tree                    as Tr
import qualified FxTradeData             as Ftd

getLearningTestTime :: Fsd.FxSettingData -> Int
getLearningTestTime fsd =
  let ls = Fsd.learningSetting $ Fsd.fxSetting fsd
  in Gsd.learningTestTimes Gsd.gsd * 
     if Fsd.numTraderadeDate ls == 0
     then 60
     else Fsd.totalTradeDate ls `div` Fsd.numTraderadeDate ls

getHoldTime :: Fsd.FxSettingData -> Int
getHoldTime fsd =
  maximum [ Fad.getSimChartMax . Fsd.fxTaOpen        $ Fsd.fxSetting fsd
          , Fad.getSimChartMax . Fsd.fxTaCloseProfit $ Fsd.fxSetting fsd
          , Fad.getSimChartMax . Fsd.fxTaCloseLoss   $ Fsd.fxSetting fsd
          ]

getPrepareTimeAll :: Fsd.FxSettingData -> Int
getPrepareTimeAll fsd =
  maximum [ getPrepareTime . Fsd.fxTaOpen        $ Fsd.fxSetting fsd
          , getPrepareTime . Fsd.fxTaCloseProfit $ Fsd.fxSetting fsd
          , getPrepareTime . Fsd.fxTaCloseLoss   $ Fsd.fxSetting fsd
          ]

getPrepareTime :: Fad.FxTechnicalAnalysisSetting -> Int
getPrepareTime x =
  maximum . M.map (\a -> maximum [ Fad.longSetting (Fad.rciSetting a)
                                 , Fad.longSetting (Fad.smaSetting a)
                                 , Fad.longSetting (Fad.emaSetting a)
                                 , Fad.longSetting (Fad.rsiSetting a)
                                 , Fad.longSetting (Fad.stSetting a)
                                 ] * Fad.getSimChartMax x) $ Fad.algoSetting x

createRandomFxAlMaSetting :: MonadRandom m => Fad.FxAlMaSetting -> m Fad.FxAlMaSetting
createRandomFxAlMaSetting ix = do
  short  <- getRandomR (max 5                                         (Fad.shortSetting  ix - Gsd.taRandomMargin Gsd.gsd),
                        max 5                                         (Fad.shortSetting  ix + Gsd.taRandomMargin Gsd.gsd))
  middle <- getRandomR (max (short  + Gsd.taMiddleLongMargin Gsd.gsd) (Fad.middleSetting ix - Gsd.taRandomMargin Gsd.gsd),
                        max (short  + Gsd.taMiddleLongMargin Gsd.gsd) (Fad.middleSetting ix + Gsd.taRandomMargin Gsd.gsd))
  long   <- getRandomR (max (middle + Gsd.taMiddleLongMargin Gsd.gsd) (Fad.longSetting   ix - Gsd.taRandomMargin Gsd.gsd),
                        max (middle + Gsd.taMiddleLongMargin Gsd.gsd) (Fad.longSetting   ix + Gsd.taRandomMargin Gsd.gsd))
  ts     <- getRandomR (max 0                            (Fad.thresholdSetting ix - fromIntegral (Gsd.taRandomMargin Gsd.gsd)),
                        min (Fad.thresholdMaxSetting ix) (Fad.thresholdSetting ix + fromIntegral (Gsd.taRandomMargin Gsd.gsd)))
  return ix { Fad.shortSetting      = short
            , Fad.middleSetting     = middle
            , Fad.longSetting       = long
            , Fad.thresholdSetting  = ts
            }

createRandomFxAlMaSettingBB :: MonadRandom m => Fad.FxAlMaSetting -> m Fad.FxAlMaSetting
createRandomFxAlMaSettingBB ix = do
  short  <- getRandomR (max 1 (Fad.shortSetting  ix - Gsd.taRandomMargin Gsd.gsd),
                        max 1 (Fad.shortSetting  ix + Gsd.taRandomMargin Gsd.gsd))
  middle <- getRandomR (max 1 (Fad.middleSetting ix - Gsd.taRandomMargin Gsd.gsd),
                        max 1 (Fad.middleSetting ix + Gsd.taRandomMargin Gsd.gsd))
  long   <- getRandomR (max 1 (Fad.longSetting   ix - Gsd.taRandomMargin Gsd.gsd),
                        max 1 (Fad.longSetting   ix + Gsd.taRandomMargin Gsd.gsd))
  return ix { Fad.shortSetting      = short
            , Fad.middleSetting     = middle
            , Fad.longSetting       = long
            }

createRandomFxAlgorithmSetting :: MonadRandom m => Fad.FxAlgorithmSetting -> m Fad.FxAlgorithmSetting
createRandomFxAlgorithmSetting ix = do
  taAndR <- getRandomR(max 1 (Fad.algorithmAndRate ix - Gsd.treeAndRate Gsd.gsd),
                       max 1 (Fad.algorithmAndRate ix + Gsd.treeAndRate Gsd.gsd))
  taOrR  <- getRandomR(max 1 (Fad.algorithmOrRate  ix - Gsd.treeOrRate  Gsd.gsd),
                       max 1 (Fad.algorithmOrRate  ix + Gsd.treeOrRate  Gsd.gsd))
  at <- Tr.makeTree taAndR taOrR (Fad.algorithmListCount ix) (Fad.algorithmTree ix)
  sc <- getRandomR (max 1 (Fad.simChart ix - Gsd.taRandomMargin Gsd.gsd), max 1 (Fad.simChart ix + Gsd.taRandomMargin Gsd.gsd))
  sma  <- createRandomFxAlMaSetting $ Fad.smaSetting  ix
  ema  <- createRandomFxAlMaSetting $ Fad.emaSetting  ix
  macd <- createRandomFxAlMaSetting $ Fad.macdSetting ix
  rci  <- createRandomFxAlMaSetting $ Fad.rciSetting  ix
  st   <- createRandomFxAlMaSetting $ Fad.stSetting   ix
  rsi  <- createRandomFxAlMaSetting $ Fad.rsiSetting  ix
  bbmf <- createRandomFxAlMaSettingBB $ Fad.bbmfSetting  ix
  bbco <- createRandomFxAlMaSettingBB $ Fad.bbcoSetting  ix
  return $ ix { Fad.algorithmTree    = at
              , Fad.algorithmAndRate = taAndR
              , Fad.algorithmOrRate  = taOrR
              , Fad.rciSetting       = rci
              , Fad.smaSetting       = sma
              , Fad.emaSetting       = ema
              , Fad.macdSetting      = macd
              , Fad.stSetting        = st
              , Fad.rsiSetting       = rsi
              , Fad.bbmfSetting        = bbmf
              , Fad.bbcoSetting        = bbco
              , Fad.simChart         = sc
              }

checkAlgoSetting :: R.MonadRandom m => Fad.FxTechnicalAnalysisSetting -> m Fad.FxTechnicalAnalysisSetting
checkAlgoSetting fts = do
  let as  = Fad.algoSetting fts
      tlc = Fad.techListCount fts
  (as'', pr) <- foldl (\acc k -> do (as', p) <- acc
                                    let x = as' M.! k
                                        (a, b) = Tr.checkLeafDataMap $ Fad.algorithmListCount x
                                        x' = x { Fad.algorithmListCount = Tr.addLeafDataMap p b }
                                        t = Tr.adjustTree (Fad.algorithmListCount x') (Fad.algorithmTree x')
                                    t' <- if t == Tr.Empty
                                          then do taAndR <- getRandomR(max 1 (Fad.algorithmAndRate x' - Gsd.treeAndRate Gsd.gsd),
                                                                       max 1 (Fad.algorithmAndRate x' + Gsd.treeAndRate Gsd.gsd))
                                                  taOrR  <- getRandomR(max 1 (Fad.algorithmOrRate  x' - Gsd.treeOrRate  Gsd.gsd),
                                                                       max 1 (Fad.algorithmOrRate  x' + Gsd.treeOrRate  Gsd.gsd))
                                                  Tr.makeTree taAndR taOrR (Fad.algorithmListCount x') Tr.Empty
                                          else return t
                                    let x'' = x' { Fad.algorithmTree = t' }
                                    return (M.insert k x'' as', a)) (pure (as, Tr.emptyLeafDataMap))
                . sort $ M.keys as
  (as''', tlc') <- if not . M.null $ Tr.getLeafDataMap pr
                   then do let nk = fst (M.findMax as'') + 1
                               tlcl = Tr.getLeafDataMap tlc
                           x <- createRandomFxAlgorithmSetting $ Fad.initFxAlgorithmSetting pr
                           return (M.insert nk x as'',
                                   Tr.LeafDataMap $ M.insert (Fad.initTechAnaLeafData nk) (0, 0) tlcl)
                   else return (as'', tlc)
  return $ fts { Fad.techListCount = tlc'
               , Fad.algoSetting   = as'''
               }

updateAlgorithmListCount :: (Fad.FxChartTaData -> M.Map Int Fad.FxTechnicalAnalysisData) ->
                            Fad.FxChartTaData ->
                            (Tr.LeafDataMap (M.Map Int Fad.FxAlgorithmSetting, M.Map Int Fad.FxTechnicalAnalysisData),
                             M.Map Int (Tr.LeafDataMap Fad.FxTechnicalAnalysisData)) ->
                            Fad.FxTechnicalAnalysisSetting ->
                            Fad.FxTechnicalAnalysisSetting
updateAlgorithmListCount f ctd (ldlt, ldla) fts =
  let tlc = Tr.addLeafDataMap ldlt (Fad.techListCount fts)
      as  = M.foldrWithKey (\k x acc -> let y = acc M.! k
                                            y' = y { Fad.algorithmListCount =
                                                     Tr.addLeafDataMap x (Fad.algorithmListCount y) }
                                        in M.insert k y' acc)
            (updateThreshold f ctd $ Fad.algoSetting fts) ldla
  in fts { Fad.techListCount = tlc
         , Fad.algoSetting   = as
         }

makeValidLeafDataMapInc :: Fad.FxTechnicalAnalysisSetting ->
                           M.Map Int Fad.FxTechnicalAnalysisData ->
                           ([Tr.LeafData (M.Map Int Fad.FxAlgorithmSetting, M.Map Int Fad.FxTechnicalAnalysisData)],
                            M.Map Int [Tr.LeafData Fad.FxTechnicalAnalysisData])
makeValidLeafDataMapInc fts ftad =
  let l = Tr.makeValidLeafDataList fst (Fad.algoSetting fts, ftad) (Fad.techAnaTree fts)
  in (l, M.fromList $ map (\x -> let n = fst $ Tr.getLeafData x
                                 in (n, Tr.makeValidLeafDataList fst (ftad M.! n) (Fad.algorithmTree $ Fad.algoSetting fts M.! n))) l)

makeValidLeafDataMapDec :: Fad.FxTechnicalAnalysisSetting ->
                           M.Map Int Fad.FxTechnicalAnalysisData ->
                           ([Tr.LeafData (M.Map Int Fad.FxAlgorithmSetting, M.Map Int Fad.FxTechnicalAnalysisData)],
                             M.Map Int [Tr.LeafData Fad.FxTechnicalAnalysisData])
makeValidLeafDataMapDec fts ftad =
  let l = Tr.makeValidLeafDataList snd (Fad.algoSetting fts, ftad) (Fad.techAnaTree fts)
  in (l, M.fromList $ map (\x -> let n = fst $ Tr.getLeafData x
                                 in (n, Tr.makeValidLeafDataList snd (ftad M.! n) (Fad.algorithmTree $ Fad.algoSetting fts M.! n))) l)

calcFxalgorithmListCount :: Double ->
                           ([Tr.LeafData (M.Map Int Fad.FxAlgorithmSetting, M.Map Int Fad.FxTechnicalAnalysisData)],
                            M.Map Int [Tr.LeafData Fad.FxTechnicalAnalysisData]) ->
                           (Tr.LeafDataMap (M.Map Int Fad.FxAlgorithmSetting, M.Map Int Fad.FxTechnicalAnalysisData),
                            M.Map Int (Tr.LeafDataMap Fad.FxTechnicalAnalysisData))
calcFxalgorithmListCount p (ptat, pat) =
  (Tr.calcValidLeafDataList p ptat, M.map (Tr.calcValidLeafDataList p) pat)

getThreshold :: Double ->
                Double ->
                Int ->
                Fad.FxChartTaData ->
                (Fad.FxTechnicalAnalysisData -> Fad.FxMovingAverageData) ->
                (Fad.FxChartTaData -> M.Map Int Fad.FxTechnicalAnalysisData) ->
                Double ->
                Double
getThreshold a b k x f1 f2 p =
  if M.member k $ f2 x
  then ((b - abs ((Fad.short  . f1 $ f2 x M.! k) - a)) +
        (b - abs ((Fad.middle . f1 $ f2 x M.! k) - a)) +
        (b - abs ((Fad.long   . f1 $ f2 x M.! k) - a)) + p) / 4
  else p

updateThreshold :: (Fad.FxChartTaData -> M.Map Int Fad.FxTechnicalAnalysisData) ->
                   Fad.FxChartTaData ->
                   M.Map Int Fad.FxAlgorithmSetting ->
                   M.Map Int Fad.FxAlgorithmSetting
updateThreshold f ctd =
  M.mapWithKey (\k x -> x { Fad.stSetting  = (Fad.stSetting x)
                            { Fad.thresholdMaxSetting = getThreshold 50 50 k ctd Fad.st f . Fad.thresholdMaxSetting $ Fad.stSetting x
                            }
                          , Fad.rciSetting = (Fad.rciSetting x)
                            { Fad.thresholdMaxSetting = getThreshold 0 100 k ctd Fad.rci f . Fad.thresholdMaxSetting $ Fad.rciSetting x
                            }
                          , Fad.rsiSetting = (Fad.rsiSetting x)
                            { Fad.thresholdMaxSetting = getThreshold 50 50 k ctd Fad.rsi f . Fad.thresholdMaxSetting $ Fad.rsiSetting x
                            }
                          })

rci :: Int -> [Double] -> Double
rci n x  =
  let r  = [1..n] :: [Int]
      r' = reverse [1..n] :: [Int]
      d = sum . map (\(a, b) -> (a - b) ^ (2 :: Int)) . zipWith (\a (_, b') -> (a, b')) r' . sort $ zip x r
  in (1 - (6.0 * fromIntegral d) / (fromIntegral n * (fromIntegral n ^ (2 :: Int) - 1))) * 100

getRci :: Int -> [Fcd.FxChartData] -> Double
getRci n x =
  let s = take n $ map Fcd.close x
  in if length s < n
     then 0
     else rci n s

rsiUpDown :: Double ->  [Double] -> (Double, Double)
rsiUpDown _ []     = (0, 0)
rsiUpDown p [x] =
  if p < x
  then (x - p, 0)
  else (0, p - x)
rsiUpDown p (x:xs) =
  let (u, d) = rsiUpDown x xs
  in if p < x
     then ((x - p) + u, d)
     else (u, (p - x) + d)

rsi :: Int -> [Double] -> Double
rsi n x =
  let (up, down) = rsiUpDown (last x) (tail $ reverse x)
      upa = up / fromIntegral n
      downa = down / fromIntegral n
  in if upa + downa == 0
     then 50
     else (100 * upa) / (upa + downa)

getRsi :: Int -> [Fcd.FxChartData] -> Double
getRsi n x =
  let s = take (n + 1) $ map Fcd.close x
  in if length s < n + 1
     then 50
     else rsi n s

getSma :: Int -> [Fcd.FxChartData] -> Double
getSma n x =
  let s = take n $ map Fcd.close x
  in if length s < n
     then 0
     else sum s / fromIntegral n

getEma :: Int -> [Fcd.FxChartData] -> Double
getEma n x =
  let s = take n $ map Fcd.close x
      h = Fcd.close $ head x
  in if length s < n
     then 0
     else (sum s + h) / (fromIntegral n + 1)

getMACD :: Double -> Double -> Int -> [Fad.FxTechnicalAnalysisData] -> (Double, Double)
getMACD es el n x =
  let macd = if es ==0 || el == 0
             then 0
             else es - el
      signal = let s = take (n - 1) x
               in if length s < (n - 1) || macd == 0
                  then 0
                  else (sum (map (Fad.short . Fad.macd) s) + macd) / fromIntegral n
  in (macd, signal)

getBB :: Fad.FxTradePosition -> Fad.FxTradePosition -> Int -> Int -> Double -> [Fcd.FxChartData] -> Fad.FxTradePosition
getBB p1 p2 n sigma ma x =
  let chart = head x
      s = take n $ map Fcd.close x
      sd = sqrt $ (fromIntegral n * foldl (\acc b -> b ^ (2 :: Int) + acc) 0 s - sum s ^ (2 :: Int)) / fromIntegral (n * (n - 1))
  in if length s < n || ma == 0
     then Fad.None
     else if ma + sd * (fromIntegral sigma / 100 + 2) < Fcd.close chart
          then p1
          else if Fcd.close chart < ma - sd * (fromIntegral sigma / 100 + 2)
               then p2
               else Fad.None

setBB :: Fad.FxTradePosition ->
         Fad.FxTradePosition ->
         Fad.FxAlMaSetting ->
         Fad.FxAlMaSetting ->
         Fad.FxMovingAverageData ->
         [Fcd.FxChartData] ->
         Fad.FxMovingAverageData
setBB p1 p2 ss bbs mad x =
  Fad.initFxMovingAverageData { Fad.thresholdS = getBB p1 p2 (Fad.shortSetting  ss) (Fad.shortSetting  bbs) (Fad.short  mad) x
                              , Fad.thresholdM = getBB p1 p2 (Fad.middleSetting ss) (Fad.middleSetting bbs) (Fad.middle mad) x
                              , Fad.thresholdL = getBB p1 p2 (Fad.longSetting   ss) (Fad.longSetting   bbs) (Fad.long   mad) x
                              }

getST :: Int -> Int -> [Fcd.FxChartData] -> [Fad.FxTechnicalAnalysisData] -> (Double, Double, Double)
getST n m x p =
  let s1 = take n $ map Fcd.close x                                   -- setting long
      s2 = take m p                                                   -- setting short
      k  = ((head s1 - minimum s1) * 100 / (maximum s1 - minimum s1)) -- short
      d  = sum (map (Fad.short  . Fad.st) s2) / fromIntegral m        -- middle
      sd = sum (map (Fad.middle . Fad.st) s2) / fromIntegral m        -- long
  in if length s1 < n || length s2 < m || maximum s1 == minimum s1
     then (50, 50, 50)
     else (k, d, sd)

setCross :: Double ->
            Double ->
            Double ->
            Double ->
            Fad.FxTradePosition
setCross s l sp lp
  | sp < lp && l < s = Fad.Buy
  | lp < sp && s < l = Fad.Sell
  | otherwise = Fad.None

setThreshold :: Double ->
                Double ->
                Double ->
                Fad.FxAlMaSetting ->
                Fad.FxTradePosition
setThreshold x tmin tmax ftms
  | x < tmin + Fad.thresholdSetting ftms = Fad.Buy
  | tmax - Fad.thresholdSetting ftms < x = Fad.Sell
  | otherwise                            = Fad.None

setFxMovingAverageData :: Double ->
                          Double ->
                          Double ->
                          Double ->
                          Double ->
                          Fad.FxAlMaSetting ->
                          (Fad.FxTechnicalAnalysisData -> Fad.FxMovingAverageData) ->
                          [Fad.FxTechnicalAnalysisData] ->
                          Fad.FxMovingAverageData
setFxMovingAverageData short middle long tmin tmax ftms g pdl =
  let fmadp = g $ head pdl
      fmad = Fad.FxMovingAverageData { Fad.short      = short
                                     , Fad.middle     = middle
                                     , Fad.long       = long
                                     , Fad.crossSL    = setCross short  long   (Fad.short fmadp)  (Fad.long fmadp)
                                     , Fad.crossSM    = setCross short  middle (Fad.short fmadp)  (Fad.middle fmadp)
                                     , Fad.crossML    = setCross middle long   (Fad.middle fmadp) (Fad.long fmadp)
                                     , Fad.thresholdS = setThreshold short  tmin tmax ftms
                                     , Fad.thresholdL = setThreshold middle tmin tmax ftms
                                     , Fad.thresholdM = setThreshold long   tmin tmax ftms
                                     }
  in fmad

makeFxMovingAverageData :: (Int -> [Fcd.FxChartData] -> Double) ->
                           Double ->
                           Double ->
                           [Fcd.FxChartData] ->
                           Fad.FxAlMaSetting ->
                           (Fad.FxTechnicalAnalysisData -> Fad.FxMovingAverageData) ->
                           [Fad.FxTechnicalAnalysisData] ->
                           Fad.FxMovingAverageData
makeFxMovingAverageData f tmin tmax lr ftms g pdl =
  let short  = f (Fad.shortSetting ftms)  lr
      middle = f (Fad.middleSetting ftms) lr
      long   = f (Fad.longSetting ftms)   lr
  in setFxMovingAverageData short middle long tmin tmax ftms g pdl

makeFxTechnicalAnalysisData :: Fad.FxAlgorithmSetting ->
                               [Fcd.FxChartData] ->
                               Fcd.FxChartData ->
                               [Fad.FxTechnicalAnalysisData] ->
                               Fad.FxTechnicalAnalysisData
makeFxTechnicalAnalysisData ftas lr chart pdl =
  let (macd, macdSignal) = getMACD (Fad.middle $ Fad.ema x) (Fad.long $ Fad.ema x) (Fad.middleSetting $ Fad.macdSetting ftas) pdl
      (k, d, sd) = getST (Fad.longSetting $ Fad.stSetting ftas) (Fad.middleSetting $ Fad.stSetting ftas) lr pdl
      x = Fad.FxTechnicalAnalysisData { Fad.chart = chart
                                      , Fad.sma   = makeFxMovingAverageData getSma 0 0 lr (Fad.smaSetting ftas) Fad.sma pdl
                                      , Fad.ema   = makeFxMovingAverageData getEma 0 0 lr (Fad.emaSetting ftas) Fad.ema pdl
                                      , Fad.macd  = setFxMovingAverageData macd 0 macdSignal 0 0 (Fad.macdSetting ftas) Fad.macd pdl
                                      , Fad.rci   = makeFxMovingAverageData getRci (-100) 100 lr (Fad.rciSetting ftas) Fad.rci pdl
                                      , Fad.st    = setFxMovingAverageData k d sd  0 100 (Fad.stSetting ftas) Fad.st pdl
                                      , Fad.rsi   = makeFxMovingAverageData getRsi 0 100 lr (Fad.rsiSetting ftas) Fad.rsi pdl
                                      , Fad.bbmf  = setBB Fad.Buy  Fad.Sell (Fad.smaSetting ftas) (Fad.bbmfSetting ftas) (Fad.sma x) lr
                                      , Fad.bbco  = setBB Fad.Sell Fad.Buy  (Fad.smaSetting ftas) (Fad.bbcoSetting ftas)  (Fad.sma x) lr
                                      }
  in if null pdl
     then Fad.initFxTechnicalAnalysisData
     else x

{-
lf [old .. new]
lr [new .. old]
-}

makeFxTechnicalAnalysisDataList :: Fad.FxAlgorithmSetting ->
                                   [Fcd.FxChartData] ->
                                   [Fcd.FxChartData] ->
                                   [Fad.FxTechnicalAnalysisData] ->
                                   [Fad.FxTechnicalAnalysisData]
makeFxTechnicalAnalysisDataList _  _             [] x = x
makeFxTechnicalAnalysisDataList fs lr (lf:lfs) x =
  let d = makeFxTechnicalAnalysisData fs (lf:lr) lf x
  in  makeFxTechnicalAnalysisDataList fs (lf:lr) lfs (d:x)

