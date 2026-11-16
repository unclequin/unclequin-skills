module Zone where

data Zone = Bkk | Central | North | Other
  deriving (Show, Eq, Ord, Enum, Bounded)

zoneFee :: Zone -> Int
zoneFee Bkk     = 40
zoneFee Central = 60
zoneFee North   = 80
zoneFee Other   = 100
