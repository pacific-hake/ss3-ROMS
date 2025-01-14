library(here)
library(ss3roms)
library(ggplot2)

### Plot of environmental drivers vs. rec devs
data(ROMS)
ROMS <- dplyr::slice(ROMS, -1)
temp <- r4ss::SSgetoutput(dirvec = 'inst/extdata/models/PacificHake') 
bifurcation <- readr::read_csv(here('data-raw', 'bifurcation_index.csv'), comment = '#') %>%
  dplyr::mutate(year = year + 1) # bifurcation index impacts preconditioning phase, recruitment year - 1
ROMS.big <- dplyr::slice(ROMS, -1) %>%
  dplyr::left_join(temp$replist$recruit[,c('Yr', 'dev')], by = c('year' = 'Yr')) %>%
  dplyr::right_join(bifurcation) %>%
  dplyr::arrange(year) %>%
  dplyr::rename(`Bifurcation index precond.` = bifurcation_index,
                `Eddy kinetic energy\nprecond.` = EKEpre.ms.c,
                `Longshore transport yolk` = LSTyolk,
                `Upwelling precond.` = UWpre.a)

ROMS.plot <- ROMS.big %>%
  tidyr::pivot_longer(cols = -c('year', 'dev'), names_to = 'indicator', values_to = 'value') %>%
  dplyr::filter(!is.na(value)) 
ROMS.cor <- ROMS.plot %>%
  dplyr::group_by(indicator) %>%
  dplyr::summarize(pearson.cor = cor(value, dev, use = 'pairwise.complete.obs'))

png('correlations.png', width = 12, height = 4, units = 'in', res = 2000)
ROMS.plot %>%
  ggplot() +
  geom_point(aes(x = value, y = dev, col = year)) +
  geom_text(x = Inf, y = Inf, hjust = 1, vjust = 1, size = 5,
            aes(label = paste('r =', round(pearson.cor, 2))), 
            data = ROMS.cor) +
  facet_wrap(~indicator, scales = 'free_x', nrow = 1) +
  labs(x = 'Environmental index', y = 'Recruitment deviation') +
  ggsidekick::theme_sleek(18) +
  scale_x_continuous(n.breaks = 4) +
  fishualize::scale_color_fish(option = 'Ostracion_whitleyi')
  #scale_color_gradientn(colors = calecopal('chaparral3',5))
dev.off()

### Retrospectives looking at including env driver

# Adjust control and data files
dat <- r4ss::SS_readdat(
  file = system.file(
    "extdata", "models", "PacificHake", "hake_data.ss",
    package = "ss3roms"
  ),
  verbose = FALSE
)
ctl <- r4ss::SS_readctl(
  file = system.file(
    "extdata", "models", "PacificHake", "hake_control.ss",
    package = "ss3roms"
  ),
  use_datlist = TRUE,
  datlist = dat,
  verbose = FALSE,
  version = 3.30
)

newlists <- add_fleet(
  datlist = dat,
  ctllist = ctl,
  data = data.frame(
    year = ROMS[["year"]],
    seas = 7,
    obs = exp(-ROMS$EKEpre.ms.c),
    se_log = 0.01
  ),
  fleetname = "env",
  fleettype = "CPUE", 
  units = 31
)
dirname <- 'test_negEKE'

r4ss::copy_SS_inputs(
  dir.old = system.file("extdata", "models", "PacificHake",
                        package = "ss3roms"
  ),
  dir.new = file.path(dirname),
  overwrite = TRUE
)

r4ss::SS_writectl(
  ctllist = newlists[["ctllist"]],
  outfile = file.path(
    dirname,
    basename(newlists[["ctllist"]][["sourcefile"]])
  ),
  overwrite = TRUE,
  verbose = FALSE
)
r4ss::SS_writedat(
  datlist = newlists[["datlist"]],
  outfile = file.path(
    dirname,
    basename(newlists[["datlist"]][["sourcefile"]])
  ),
  overwrite = TRUE,
  verbose = FALSE
)

# Run SS in MLE mode
r4ss::run_SS_models(dirvec = c('test_negEKE','inst/extdata/models/PacificHake'), 
                    skipfinished = FALSE, 
                    model = 'inst/extdata/bin/Windows64/ss')

# Do retrospectives
r4ss::SS_doRetro(
  masterdir = here('inst/extdata/models'),
  oldsubdir = 'PacificHake',
  years = -(10:15)
)

r4ss::SS_doRetro(masterdir = here('test_negEKE'),
                 oldsubdir = '', 
                 years = -(10:15)
)
 
temp <- r4ss::SSgetoutput(dirvec = c(here('inst/extdata/models', 'retrospectives', 'retro-15'),
                                     here('test_negEKE', 'retrospectives', 'retro-15'),
                                     here('inst/extdata/models/PacificHake')),
                          forecast = FALSE) %>%
  r4ss::SSsummarize()

rec.devs <- temp$recdevs
names(rec.devs)[1:7] <- c(paste0('retro', 10:15), 'age1.2021')
for(ii in 1:nrow(rec.devs)) {
  for(jj in 1:6) {
    if(rec.devs$Yr[ii] > 2020-(10:15)[jj]) {
      rec.devs[ii,jj] <- NA
    }
  }
}

names(rec.devs)[1:3] <- c('Age 1 2006 retro', 'Env 2006 retro', '2021 Age 1')
rec.devs[rec.devs$Yr > 2006, 1:2] <- NA
plot.dat <- rec.devs %>%
  tidyr::pivot_longer(cols = 1:3, names_to = 'model', values_to = 'rec.dev') %>%
  dplyr::filter(!grepl('Early|Late|Fore', Label), 
                Yr > 1990) %>%
  dplyr::mutate(model = factor(model))

big.plot <- plot.dat %>%
  ggplot() +
  geom_line(aes(x = Yr, y = rec.dev, col = model)) +
 # geom_line(aes(x = Yr, y = age1.2021)) +
  ggsidekick::theme_sleek(18) +
  labs(x = 'Year', y = 'Recruitment deviation') +
  geom_hline(yintercept = 0, col = 'red') +
  scale_color_manual(values = inauguration::inauguration('inauguration_2021', 3), drop = FALSE)

png('assess_skill.png', width = 11, height = 4.5, units = 'in', res = 2000)
big.plot +
  geom_point(aes(x = Yr, y = rec.dev, col = model), cex = 2,
             data = dplyr::filter(plot.dat, Yr==2006))
dev.off()

png('assess_skill0.png', width = 11, height = 4.5, units = 'in', res = 2000)
big.plot %+%
  dplyr::filter(plot.dat, model == '2021 Age 1') +
  geom_point(aes(x = Yr, y = rec.dev, col = model), cex = 2,
             data = dplyr::filter(plot.dat, Yr == 2006, model == '2021 Age 1'))
  
dev.off()

temp %>%
  r4ss::SSsummarize() %>%
  r4ss::SSplotRetroRecruits(cohorts = 2000:2010, endyrvec = 2020 - 10:15)



qplot(x = year, y = bifurcation_index, geom = 'line', data = bifurcation)
