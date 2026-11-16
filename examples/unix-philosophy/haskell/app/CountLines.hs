module Main (main, countLines, countLinesInFile) where

import Data.Text (Text)
import qualified Data.Text as T
import qualified Data.Text.IO as TIO

-- Hard to compose: logic tied to a file
countLinesInFile :: FilePath -> IO Int
countLinesInFile path = countLines <$> TIO.readFile path

-- Composable: pure function over text; works with stdin, files, tests
countLines :: Text -> Int
countLines = length . T.lines

main :: IO ()
main = TIO.getContents >>= print . countLines
