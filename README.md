# videoabstracts

Scripts for managing conference video abstracts.

### About

I wrote these scripts for creating packaged video abstracts for PLDI'15.   The general idea is that authors will submit videos (via some other system, such as a google form), and that these scripts will package the videos in a standard format with front and back matter to match the conference program.



### Dependencies

#### Software

|Program|Description|
|---|---|
|perl|Sorry!|
|perf FFmpeg library||
|ffmpeg|Video manipulation software.|
|mmcat|Concatenates video files.  See [here](https://trac.ffmpeg.org/wiki/mmcat)|

#### Data Files

|File | Description|
|---|---|
|aec.csv|list of paper numbers that passed artifact evaluation committee.|
|rowid.log|log file providing hashes for google drive hosting finished videos.|
|schedule.csv|confence schedule, listed as paper name, session number, and talk number|
|sessions.csv|session numbers, names, track color, day, start time, length|
|videos.tsv|google form output: timestamp, paper number, paper title, poster?, video url, email.  See [this](https://stackoverflow.com/questions/15057907/how-to-get-the-file-id-so-i-can-perform-a-download-of-a-file-from-google-drive-a).|

#### Art Files

