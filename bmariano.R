library(stringr)
library(jsonlite)
library(tidyverse)
#Cleaning and beginning to summarize song data using tidyverse


all.song.files = tibble(filepath = list.files(path = "EssentiaOutput", full.names = TRUE, recursive = TRUE)) |>
  mutate(count = str_count(filepath, ".json")) |>
  filter(count == 1) |>
  pull(filepath)

#Data frame to be added to
total_data = tibble(artist = character(), 
                    album = character(), 
                    track = character(), 
                    overall_loudness = numeric(), 
                    spectral_energy = numeric(), 
                    dissonance = numeric(),
                    pitch_salience = numeric(), 
                    bpm = numeric(), 
                    beat_loudness = numeric(), 
                    danceability = numeric(), 
                    tuning_frequency = numeric())
#Data frame to be repeatedly filled
new_data = tibble(artist = character(1), 
                  album = character(1), 
                  track = character(1), 
                  overall_loudness = numeric(1), 
                  spectral_energy = numeric(1), 
                  dissonance = numeric(1),
                  pitch_salience = numeric(1), 
                  bpm = numeric(1), 
                  beat_loudness = numeric(1), 
                  danceability = numeric(1), 
                  tuning_frequency = numeric(1))
#Creates data frame containing new indicators for each song (ex: valence and arousal)
#Will be reused
newCols = tibble(avg.valence = numeric(1), 
                 avg.arousal = numeric(1), 
                 aggressive = numeric(1),
                 happy = numeric(1), 
                 party = numeric(1), 
                 relaxed = numeric(1), 
                 sad = numeric(1), 
                 acoustic = numeric(1), 
                 electric =numeric(1), 
                 instrumental = numeric(1))
#Creates data frame containing new indicators for each song (ex: valence and arousal)
#Will store the values for every song
allNewVals = tibble(avg.valence = c(), 
                    avg.arousal = c(), 
                    aggressive = c(), 
                    happy = c(), 
                    party = c(), 
                    relaxed = c(), 
                    sad = c(), 
                    acoustic = c(), 
                    electric = c(), 
                    instrumental = c())
#Reads through CSV file
csvFile = read_csv("EssentiaOutput/EssentiaModelOutput.csv")
i = 1
#Cycles through each of the 181 song files (Goes through in order)
for(ind in 1:length(all.song.files))
{
  current.filename= all.song.files[ind] 

  #Contains track info
  song.info = fromJSON(current.filename)
  #Splits the file-name
  split.file = str_split(current.filename,"-")
  #Code below finds artist, album and track
  split.file = split.file[[1]]
  new_data = new_data |>
    #Finds artist name and removes  "EssentiaOutput/" 
    mutate(artist = str_sub(split.file[1], start = 16)) |>
    mutate(album = split.file[2]) |>
    #Removes the.json portion that is attached to the track
    mutate(track = str_sub(split.file[3], start = 1, end = -6)) |>
    #Finds values for each song
    #MAY NEED TO FIX OVERALL LOUDNESS (where it is found)
    mutate(overall_loudness = song.info$lowlevel$loudness_ebu128$integrated) |>
    mutate(spectral_energy = song.info$lowlevel$spectral_energy$mean) |> 
    mutate(dissonance = song.info$lowlevel$dissonance$mean) |> 
    mutate(pitch_salience = song.info$lowlevel$pitch_salience$mean) |>
    mutate(bpm = song.info$rhythm$bpm) |>
    mutate(beat_loudness = song.info$rhythm$beats_loudness$mean) |>
    mutate(danceability = song.info$rhythm$danceability) |>
    mutate(tuning_frequency = song.info$tonal$tuning_frequency) 
  #Step 3:
  #2 
  newCols = newCols |>
    mutate(avg.valence = mean(c(csvFile$deam_valence[i], csvFile$emo_valence[i], csvFile$muse_valence[i]), na.rm = TRUE)) |>
    mutate(avg.arousal = mean(c(csvFile$deam_arousal[i], csvFile$emo_arousal[i], csvFile$muse_arousal[i]), na.rm = TRUE)) |>
    #3. Finds aggressive, happy, party, relaxed, and sad
    mutate(aggressive = mean(c(csvFile$eff_aggressive[i], csvFile$nn_aggressive[i]), na.rm = TRUE)) |>
    mutate(happy = mean(c(csvFile$eff_happy[i], csvFile$nn_happy[i]), na.rm = TRUE)) |>
    mutate(party = mean(c(csvFile$eff_party[i], csvFile$nn_party[i]), na.rm = TRUE)) |>
    mutate(relaxed = mean(c(csvFile$eff_relax[i], csvFile$nn_relax[i]), na.rm = TRUE)) |>
    mutate(sad = mean(c(csvFile$eff_sad[i], csvFile$nn_sad[i], na.rm = TRUE))) |>
    #4 Finds Acoustic and Electric
    mutate(acoustic = mean(c(csvFile$eff_acoustic[i], csvFile$nn_acoustic[i]), na.rm = TRUE)) |>
    mutate(electric = mean(c(csvFile$eff_electronic[i], csvFile$nn_electronic[i]), na.rm = TRUE)) |>
    #5 Finds instrumental
    mutate(instrumental = mean(c(csvFile$eff_instrumental[i], csvFile$nn_instrumental[i]), na.rm = TRUE))


  #2. 
  #Appends new_data to total_data (new_data is a row)
  #This stores
  total_data = total_data |>
    bind_rows(new_data)
  #Appends the new indicators for each song
  allNewVals = allNewVals |>
    bind_rows(newCols)
  i = i + 1
}

#6 Changes name of timbre column
csvFile = csvFile |>
  rename(timbreBright = eff_timbre_bright)

#Combines the allNewVals data frame with existing csv File
for(column.ind in 1:ncol(allNewVals))
{
  csvFile = csvFile |> 
    bind_cols(allNewVals[][column.ind]) 
}

#7 Subsets columns
csvFile = csvFile |>
  select(artist,album, track, avg.valence, avg.arousal, aggressive, happy, party
                                     , relaxed, sad, acoustic, electric, instrumental, timbreBright)

#Step 4:

liwcFile = read_csv("LIWCOutput/LIWCOutput.csv")
merged = total_data |>
  left_join(csvFile, by = c( "artist", "album", "track")) |>
  left_join(liwcFile, by = c("artist", "album", "track"))

#Changes name of function to funct
colnames(merged)[colnames(merged) == "function."] = "funct"
#Removes Allentown
csv.without.atown = merged |>
  filter(track != "Allentown")
write_csv(csv.without.atown, file = "trainingdata.csv")
#Only keeps Allentown
csv.with.atown = merged |> 
  filter(track == "Allentown")
write_csv(csv.with.atown, file = "testingdata.csv")

#Coding Challenge
#Going to assess differences in indicators for the song (including lyrics)
View(merged)


#Analyzes the differences in avg.valence among artists
####################################
# Load Data
####################################
dat <- read_csv("trainingdata.csv")
####################################
# Select data for plot
####################################
df <- dat %>%
  dplyr::select("avg.valence", "artist") %>%
  filter(!is.na(!!sym("artist")))
####################################
# Create Plot
####################################
p <- ggplot(df, aes(x = !!sym("artist"), y = !!sym("avg.valence"))) +
  geom_boxplot(fill = "lightgrey", width = 0.5) +
  get("theme_bw")() +
  xlab("artist") +
  ylab("avg.valence") +
  ggtitle("", "")
####################################
# Print Plot
####################################
p
####################################
# Summarize Data
####################################
dat.summary <- dat %>%
  select(!!sym("avg.valence"), !!sym("artist")) %>%
  group_by(!!sym("artist")) %>%
  summarize(Observations = sum(!is.na(!!sym("avg.valence"))), Mean = mean(!!sym("avg.valence"), na.rm = T), `Standard Deviation` = sd(!!sym("avg.valence"), na.rm = T), Min = min(!!sym("avg.valence"), na.rm = T), Q1 = quantile(!!sym("avg.valence"), probs = 0.25, na.rm = T), Median = median(!!sym("avg.valence"), na.rm = T), Q3 = quantile(!!sym("avg.valence"), probs = 0.75, na.rm = T), Max = max(!!sym("avg.valence"), na.rm = T), IQR = IQR(!!sym("avg.valence"), na.rm = T)) %>%
  filter(!is.na(!!sym("artist"))) %>%
  tidyr::complete(!!sym("artist")) %>%
  mutate_if(is.numeric, round, 4)
missing.obs <- dat %>%
  summarize(missing = sum(is.na(!!sym("avg.valence")) | is.na(!!sym("artist")))) %>%
  pull(missing)
dat.summary <- dat.summary %>%
  ungroup() %>%
  add_row(`:=`(!!sym("artist"), "Rows with Missing Data"), Observations = missing.obs, Mean = NA, `Standard Deviation` = NA, Min = NA, Q1 = NA, Median = NA, Q3 = NA, Max = NA, IQR = NA)
####################################
# Print Data Summary
####################################
dat.summary

#Analyzes Instrumental indicator
####################################
# Load Data
####################################
dat <- read_csv("trainingdata.csv")
####################################
# Select data for plot
####################################
df <- dat %>%
  dplyr::select("instrumental", "artist") %>%
  filter(!is.na(!!sym("artist")))
####################################
# Create Plot
####################################
p <- ggplot(df, aes(x = !!sym("artist"), y = !!sym("instrumental"))) +
  geom_boxplot(fill = "lightgrey", width = 0.5) +
  get("theme_bw")() +
  xlab("artist") +
  ylab("instrumental") +
  ggtitle("", "")
####################################
# Print Plot
####################################
p
####################################
# Summarize Data
####################################
dat.summary <- dat %>%
  select(!!sym("instrumental"), !!sym("artist")) %>%
  group_by(!!sym("artist")) %>%
  summarize(Observations = sum(!is.na(!!sym("instrumental"))), Mean = mean(!!sym("instrumental"), na.rm = T), `Standard Deviation` = sd(!!sym("instrumental"), na.rm = T), Min = min(!!sym("instrumental"), na.rm = T), Q1 = quantile(!!sym("instrumental"), probs = 0.25, na.rm = T), Median = median(!!sym("instrumental"), na.rm = T), Q3 = quantile(!!sym("instrumental"), probs = 0.75, na.rm = T), Max = max(!!sym("instrumental"), na.rm = T), IQR = IQR(!!sym("instrumental"), na.rm = T)) %>%
  filter(!is.na(!!sym("artist"))) %>%
  tidyr::complete(!!sym("artist")) %>%
  mutate_if(is.numeric, round, 4)
missing.obs <- dat %>%
  summarize(missing = sum(is.na(!!sym("instrumental")) | is.na(!!sym("artist")))) %>%
  pull(missing)
dat.summary <- dat.summary %>%
  ungroup() %>%
  add_row(`:=`(!!sym("artist"), "Rows with Missing Data"), Observations = missing.obs, Mean = NA, `Standard Deviation` = NA, Min = NA, Q1 = NA, Median = NA, Q3 = NA, Max = NA, IQR = NA)
####################################
# Print Data Summary
####################################
dat.summary

#Graphs spectral energy
####################################
# Load Data
####################################
dat <- read_csv("trainingdata.csv")
####################################
# Select data for plot
####################################
df <- dat %>%
  dplyr::select("spectral_energy", "artist") %>%
  filter(!is.na(!!sym("artist")))
####################################
# Create Plot
####################################
p <- ggplot(df, aes(x = !!sym("artist"), y = !!sym("spectral_energy"))) +
  geom_boxplot(fill = "lightgrey", width = 0.5) +
  get("theme_bw")() +
  xlab("artist") +
  ylab("spectral_energy") +
  ggtitle("", "")
####################################
# Print Plot
####################################
p
####################################
# Summarize Data
####################################
dat.summary <- dat %>%
  select(!!sym("spectral_energy"), !!sym("artist")) %>%
  group_by(!!sym("artist")) %>%
  summarize(Observations = sum(!is.na(!!sym("spectral_energy"))), Mean = mean(!!sym("spectral_energy"), na.rm = T), `Standard Deviation` = sd(!!sym("spectral_energy"), na.rm = T), Min = min(!!sym("spectral_energy"), na.rm = T), Q1 = quantile(!!sym("spectral_energy"), probs = 0.25, na.rm = T), Median = median(!!sym("spectral_energy"), na.rm = T), Q3 = quantile(!!sym("spectral_energy"), probs = 0.75, na.rm = T), Max = max(!!sym("spectral_energy"), na.rm = T), IQR = IQR(!!sym("spectral_energy"), na.rm = T)) %>%
  filter(!is.na(!!sym("artist"))) %>%
  tidyr::complete(!!sym("artist")) %>%
  mutate_if(is.numeric, round, 4)
missing.obs <- dat %>%
  summarize(missing = sum(is.na(!!sym("spectral_energy")) | is.na(!!sym("artist")))) %>%
  pull(missing)
dat.summary <- dat.summary %>%
  ungroup() %>%
  add_row(`:=`(!!sym("artist"), "Rows with Missing Data"), Observations = missing.obs, Mean = NA, `Standard Deviation` = NA, Min = NA, Q1 = NA, Median = NA, Q3 = NA, Max = NA, IQR = NA)
####################################
# Print Data Summary
####################################
dat.summary

#What the Data tells us
allentown.valence = csv.with.atown |>
  pull(avg.valence)
#value: 4.046
#Aligns most closely with Manchester Orchestra which has a median of 4.28 vs
#The Front Bottoms who have a median of 4.51
allentown.instrumental = csv.with.atown |>
  pull(instrumental)
#value: 0.179
#Aligns most closely with the Manchester Orchestra which has a median of .207 vs 
#The Front Bottoms who have a median of 0.294
allentown.spec.energy = csv.with.atown |> 
  pull(spectral_energy)
#value: 0.029
#Aligns most closely with the Manchester Orchestra which has a median of .0281 vs
#The Front Bottoms who have a median of .0367

