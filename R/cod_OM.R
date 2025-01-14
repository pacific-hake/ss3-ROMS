library(dplyr)
library(doParallel)
library(future)
library(r4ss)
library(ss3sim)
library(here)
source('R/add_fleet.R')

# set ss3 executable location
if(Sys.info()['sysname'] == 'Linux'){
  exe_loc = system.file(file.path("bin", "Linux64", "ss3"), package = "ss3sim")
} else {
  exe_loc = system.file(file.path("bin", "Windows64", "ss3.exe"), package = "ss3sim")
}

# Adjust cod operating model ----------------------------------------------

# cod.loc <- system.file(file.path("extdata", "models"), package = "ss3sim")
# 
# dir.create('inst/extdata/models/Cod')
# file.copy(cod.loc, 'inst/extdata/models/Cod', recursive = TRUE)
# file.rename(from = 'inst/extdata/models/Cod/models',
#             to = 'inst/extdata/models/Cod/original')

cod <- SS_read('inst/extdata/models/Cod/original/cod-om')

# get rid of CPUE data from fishery. this is weird. and it breaks add_fleet function.
cod$ctl$Q_options <- cod$ctl$Q_options['Survey',]
cod$ctl$Q_parms <- cod$ctl$Q_parms[grep('Survey', rownames(cod$ctl$Q_parms)),]
cod$dat$CPUE <- filter(cod$dat$CPUE, index == which(cod$dat$fleetnames == 'Survey'))

# extend number of years (will be forecast in the EM)
cod$dat$endyr <- 112

# remove recdev sum to zero constraint
cod$ctl$do_recdev <- 2

# change forecast buffer so fish are actually caught!
cod$fore$Flimitfraction <- 1

# move selectivity curve right to give index a shot
cod$ctl$size_selex_parms$INIT[grep('1_Fishery', rownames(cod$ctl$size_selex_parms))] <- 100
cod$ctl$size_selex_parms$INIT[grep('1_Survey', rownames(cod$ctl$size_selex_parms))] <- 75
cod$ctl$size_selex_parms$HI[grep('P_1', rownames(cod$ctl$size_selex_parms))] <- 150
cod$ctl$size_selex_parms$LO[grep('P_1', rownames(cod$ctl$size_selex_parms))] <- 20

# considered decreasing steepness, but popn is not depleted so doesn't matter

cod.env <- add_fleet(datlist = cod$dat, ctllist = cod$ctl, 
                     data = data.frame(matrix(1, nrow = 1, ncol = 4)), 
                     fleettype = 'CPUE', fleetname = 'env', units = 36)
cod.env$ctllist$Q_options['env','extra_se'] <- 0
cod.env$ctllist$Q_options['env','float'] <- 0
cod.env$ctllist$Q_parms <- cod.env$ctllist$Q_parms[-grep('extraSD', rownames(cod.env$ctllist$Q_parms)),]
cod.env$ctllist$Q_parms['LnQ_base_env(3)', 'LO'] <- 0.001 # this is actually q for index type 36, and must be >0
cod.env$ctllist$Q_parms['LnQ_base_env(3)', 'INIT'] <- 1

cod$dat <- cod.env$datlist
cod$ctl <- cod.env$ctllist

SS_write(cod, 'inst/extdata/models/Cod/OM', overwrite = TRUE)
ss3sim::create_em(dir_in = 'inst/extdata/models/Cod/OM', 
                  dir_out = 'inst/extdata/models/Cod/EM')
# run('inst/extdata/models/cod/OM', exe = here('inst/extdata/models/ss.exe'), extras = '-nohess', show_in_console = TRUE)


# simulate OM and 1st EM scenario -----------------------------------------

df <- setup_scenarios_defaults()

# decrease comp sample sizes
# df$sl.Nsamp.1 <- 25
# df$sl.Nsamp.2 <- 50
# df$sa.Nsamp.1 <- 25
# df$sa.Nsamp.2 <- 50
  
# rec index
df$si.years.3 <- '90:100'
df$si.sds_obs.3 <- 0.1
df$si.seas.3 <- 1

# last 12 yrs of data are forecast
df$ce.forecast_num <- 12
df$cf.years.1 <- '26:112'
df$cf.fvals.1 <- 'rep(0.1052, 87)'

# model location, etc.
df$om_dir <- 'inst/extdata/models/Cod/OM'
df$em_dir <- 'inst/extdata/models/Cod/EM'
df$bias_adjust <- FALSE
rec_flt_ind <- 3

tictoc::tic()
ncore <- parallelly::availableCores()
cl <- makeCluster(ncore - 1)
registerDoParallel(cl)
nsim <- 100
sim_dir <- 'cod_10'
set.seed(52890)

scname <- run_ss3sim(iterations = 1:nsim, simdf = df, extras = '-nohess', 
                     parallel = TRUE, parallel_iterations = TRUE,
                     scenarios = file.path(sim_dir, df[,paste0('si.sds_obs.', rec_flt_ind)]))
stopCluster(cl)


# Run EM without index ----------------------------------------------------

dir.create(file.path(sim_dir, 'no_ind'))
plan(multisession, workers = ncore-1)

furrr::future_walk(1:nsim, \(iter) {
  # copy files, read in EM
  file.copy(from = file.path(sim_dir, df$si.sds_obs.3, iter),
            to = file.path(sim_dir, 'no_ind'), 
            recursive = TRUE, overwrite = TRUE)
  mod <- SS_read(file.path(sim_dir, 'no_ind', iter, 'em'))
  
  # remove index
  mod$dat$CPUE <- mod$dat$CPUE[mod$dat$CPUE$index != rec_flt_ind,]
  mod$ctl$Q_options <- mod$ctl$Q_options[-grep('env', rownames(mod$ctl$Q_options)),]
  mod$ctl$Q_parms <- mod$ctl$Q_parms[-grep('env', rownames(mod$ctl$Q_parms)),]
  
  # set forecast F to historic F
  om_dat <- SS_readdat(file.path(sim_dir, 'no_ind', iter, "om", 'data_expval.ss'), 
                       verbose = FALSE)
  mod$fore$ForeCatch <- filter(om_dat$catch, year > (om_dat$endyr-12)) |>
    rename(Year = year, Seas = seas, Fleet = fleet,
           `Catch or F` = catch) |>
    select(-catch_se)
  mod$fore$FirstYear_for_caps_and_allocations <- om_dat$endyr + 1

  # write model and run
  SS_write(mod, file.path(sim_dir, 'no_ind', iter, 'em'), overwrite = TRUE)
  r4ss::run(dir = file.path(sim_dir, 'no_ind', iter, 'em'),
      exe = exe_loc, verbose = FALSE,
      # extras = '-nohess', # conducting bias adjustment
      skipfinished = FALSE)
  bias <- ss3sim:::calculate_bias(
    dir = file.path(sim_dir, 'no_ind', iter, 'em'),
    ctl_file_in = "em.ctl"
  )
  r4ss::run(dir = file.path(sim_dir, 'no_ind', iter, 'em'),
      exe = exe_loc, verbose = FALSE,
      extras = '-nohess', 
      skipfinished = FALSE)
  
  unlink(file.path(sim_dir, 'no_ind', iter, 'em', 'bias_00'), recursive = TRUE)
})

# Run EM under different index SDs ----------------------------------------

# based on earlier simulations, > 0.5 all look the same
# want more contrast at lower values.
file.rename(from = file.path(sim_dir, '0.1'),
            to = file.path(sim_dir, 'base'))
sd_seq <- c(0.05, 0.1, 0.2, 0.3, 0.5)
purrr::walk(sd_seq, \(sd) dir.create(file.path(sim_dir, sd)))

furrr::future_walk(1:nsim, \(iter) {
  mod <- SS_read(file.path(sim_dir, 'base', iter, 'em'))
  rec_yrs <- mod$dat$CPUE$year[mod$dat$CPUE$index == rec_flt_ind]
  
  # First replace survey obs with expected values if needed.
  if(any(is.nan(mod$dat$CPUE$obs))) {
    warning('replacing NaNs in index with rec dev. SS3 may not behave as expected.')
    om_res <- r4ss::SS_output(file.path(sim_dir, 'base', iter, "om"),
                              forecast = FALSE, warn = FALSE, covar = FALSE,
                              readwt = FALSE, verbose = FALSE,
                              printstats = FALSE)
    rec_devs <- dplyr::filter(om_res$recruit, Yr %in% rec_yrs) |>
      dplyr::pull(dev)
    mod$dat$CPUE$obs[mod$dat$CPUE$year %in% rec_yrs &
                       mod$dat$CPUE$index == rec_flt_ind] <- rec_devs
  }
  
  # set forecast F to historic F
  om_dat <- SS_readdat(file.path(sim_dir, 'base', iter, "om", 'data_expval.ss'), 
                       verbose = FALSE)
  mod$fore$ForeCatch <- filter(om_dat$catch, year > (om_dat$endyr-12)) |>
    rename(Year = year, Seas = seas, Fleet = fleet,
           `Catch or F` = catch) |>
    select(-catch_se)
  mod$fore$FirstYear_for_caps_and_allocations <- om_dat$endyr + 1

  seed <- sample(100000000, 1)
  # now sample survey index across new SDs
  purrr::walk(sd_seq, \(s.d) {
    # ensure same seed for all SEs per iteration
    set.seed(seed)
    tmp_dat <- sample_index(mod$dat, fleets = rec_flt_ind, 
                            years = list(rec_yrs), 
                            sds_obs = list(s.d))
    mod$dat$CPUE[mod$dat$CPUE$index == rec_flt_ind,] <- tmp_dat$CPUE
    
    # copy OM, write model and run
    dir.create(file.path(sim_dir, s.d, iter))
    file.copy(from = file.path(sim_dir, 'base', iter, 'om'),
              to = file.path(sim_dir, s.d, iter), 
              recursive = TRUE, overwrite = TRUE)
    SS_write(mod, file.path(sim_dir, s.d, iter, 'em'), overwrite = TRUE)
    r4ss::run(dir = file.path(sim_dir, s.d, iter, 'em'),
        exe = exe_loc, verbose = FALSE,
        # extras = '-nohess', 
        skipfinished = FALSE)
    bias <- ss3sim:::calculate_bias(
      dir = file.path(sim_dir, s.d, iter, 'em'),
      ctl_file_in = "em.ctl"
    )
    r4ss::run(dir = file.path(sim_dir, s.d, iter, 'em'),
        exe = exe_loc, verbose = FALSE,
        extras = '-nohess', 
        skipfinished = FALSE)
    unlink(file.path(sim_dir, s.d, iter, 'em', 'bias_00'), recursive = TRUE)
  })
}, .options = furrr::furrr_options(seed = 5890238))


# 0.1 index but only last 3 yrs ----------------------------------------------------
# 
# dir.create(file.path(sim_dir, '0.1_end_yrs_only'))
# 
# furrr::future_walk(1:nsim, \(iter) {
#   # copy files, read in EM
#   file.copy(from = file.path(sim_dir, '0.1', iter),
#             to = file.path(sim_dir, '0.1_end_yrs_only'), 
#             recursive = TRUE, overwrite = TRUE)
#   mod <- SS_read(file.path(sim_dir, '0.1_end_yrs_only', iter, 'em'))
#   
#   # remove index
#   mod$dat$CPUE <- filter(mod$dat$CPUE, year > 97 | index == 2)
#   
#   # write model and run
#   SS_write(mod, file.path(sim_dir, '0.1_end_yrs_only', iter, 'em'), overwrite = TRUE)
#   run(dir = file.path(sim_dir, '0.1_end_yrs_only', iter, 'em'),
#       exe = exe_loc, verbose = FALSE,
#       extras = '-nohess', skipfinished = FALSE)
# })

tictoc::toc()

future::plan(future::sequential)
tictoc::tic()
sim_res <- get_results_all(directory = sim_dir, 
                           user_scenarios = c(0.05, 0.1, 0.2, 0.3, 0.5, 'no_ind'),
                           overwrite_files = TRUE)
tictoc::toc()

