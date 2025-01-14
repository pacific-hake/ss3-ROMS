library(ggplot2)
library(dplyr)
library(r4ss)
theme_set(theme_classic(base_size = 14))

hake <- SS_output('inst/extdata/models/PacificHake', covar = FALSE, 
                     verbose = FALSE, printstats = FALSE)
hake$recruit |> 
  select(Yr, raw_dev) |>
  filter(Yr < 2020, Yr > 1990) |>
  ggplot() +
  geom_line(aes(x = Yr, y = raw_dev), col = rgb(35, 74, 131, maxColorValue = 255)) +
  geom_hline(yintercept = 0) +
  labs(x = 'Year', y = 'Recruitment deviation')
ggsave(filename = 'wfc_figs/hake_recdev.png', device = 'png', dpi = 500, width = 10, height = 5)

ts <- readr::read_csv('bias_adjust/ss3sim_ts.csv') |>
  mutate(scenario = ifelse(scenario == 'no_ind', 'No index', scenario))
scalar <- readr::read_csv('bias_adjust/ss3sim_scalar.csv')  |>
  mutate(scenario = ifelse(scenario == 'no_ind', 'No index', scenario))
dq <- readr::read_csv('bias_adjust/ss3sim_dq.csv') |>
  mutate(scenario = ifelse(scenario == 'no_ind', 'No index', scenario))
dq_zero_sum <- readr::read_csv('sims/ss3sim_dq.csv') |>
  mutate(scenario = ifelse(scenario == 'no_ind', 'No index', scenario))


lty_vec <- c(2, rep(1, 6)) |>
  `names<-`(c('Oper. mod.', rev(unique(ts$scenario))))
scenario_ex <- ts |> 
  filter(model_run == 'em' | scenario == 'No index', iteration == 25) |>
  mutate(Model = factor(ifelse(model_run == 'om', 'Oper. mod.', scenario))) |>
  mutate(Model = forcats::fct_rev(Model)) |>
  ggplot() +
  geom_rect(xmin = 100, xmax = 112, ymin = 0, ymax = max(ts$Bio_smry), fill = 'gray90') +
  geom_rect(xmin = 0, xmax = 26, ymin = 0, ymax = max(ts$Bio_smry), fill = 'gray90') +
  geom_line(aes(x = year, y = SpawnBio, col = Model, lty = Model, alpha = Model), 
            linewidth = 1) +
  scale_color_manual(values = c('gray50', LaCroixColoR::lacroix_palette('Orange', 6))) +
  labs(x = 'Year', y = 'Spawning Biomass') +
  scale_y_continuous(labels = NULL)

# OM only
scenario_ex +
  scale_linetype_manual(values = lty_vec) +
  scale_alpha_manual(values = c(1, rep(0, 6)))
ggsave('wfc_figs/scenario_ex1.png', device = 'png', width = 8, height = 4, dpi = 500)

# OM + 1 EM no forecast, there is probably a better way to do this
ts |>
  filter(model_run == 'em' | scenario == 'No index', iteration == 25) |>
  mutate(Model = factor(ifelse(model_run == 'om', 'Oper. mod.', scenario))) |>
  mutate(Model = forcats::fct_rev(Model)) |>
  filter(Model == 'Oper. mod.' | year <= 100) |>
  ggplot() +
  geom_rect(xmin = 100, xmax = 112, ymin = 0, ymax = max(ts$Bio_smry), fill = 'gray90') +
  geom_rect(xmin = 0, xmax = 26, ymin = 0, ymax = max(ts$Bio_smry), fill = 'gray90') +
  geom_line(aes(x = year, y = SpawnBio, col = Model, lty = Model, alpha = Model), 
            linewidth = 1) +
  scale_color_manual(values = c('gray50', LaCroixColoR::lacroix_palette('Orange', 6))) +
  labs(x = 'Year', y = 'Spawning Biomass') +
  scale_y_continuous(labels = NULL) +
  scale_linetype_manual(values = lty_vec) +
  scale_alpha_manual(values = c(1, 1, rep(0, 5)))
ggsave('wfc_figs/scenario_ex2.png', device = 'png', width = 8, height = 4, dpi = 500)

# OM + 1 EM forecast
scenario_ex +
  scale_linetype_manual(values = lty_vec) +
  scale_alpha_manual(values = c(1, 1, rep(0, 5)))
ggsave('wfc_figs/scenario_ex3.png', device = 'png', width = 8, height = 4, dpi = 500)

# OM + all EMs
scenario_ex +
  scale_linetype_manual(values = lty_vec) +
  scale_alpha_manual(values = rep(1, 7))
ggsave('wfc_figs/scenario_ex4.png', device = 'png', width = 8, height = 4, dpi = 500)

# Recruitment year 100
ts |> 
  filter(year == 100) |>
  tidyr::pivot_wider(names_from = model_run, values_from = Recruit_0, 
                     id_cols = c(iteration, scenario)) |>
  mutate(are = abs((em-om)/om),
         rel_err = (em - om)/om) |> 
  group_by(scenario) |>
  ggplot() +
  geom_violin(aes(x = scenario, y = rel_err, fill = scenario), 
              alpha = 0, col = 'white') +
  geom_hline(yintercept = 0, color = 'black') +
  scale_fill_manual(values = rev(LaCroixColoR::lacroix_palette('Orange', 6))) +
  theme(legend.position = 'none') +
  labs(x = 'Index SE', y = 'Relative error of terminal\nyear recruitment')
ggsave('wfc_figs/rec_100_axes.png', device = 'png', width = 8, height = 4, dpi = 500)

ts |> 
  filter(year == 100) |>
  tidyr::pivot_wider(names_from = model_run, values_from = Recruit_0, 
                     id_cols = c(iteration, scenario)) |>
  mutate(are = abs((em-om)/om),
         rel_err = (em - om)/om) |> 
  group_by(scenario) |>
  ggplot() +
  geom_violin(aes(x = scenario, y = rel_err, fill = scenario)) +
  geom_hline(yintercept = 0, color = 'black') +
  scale_fill_manual(values = rev(LaCroixColoR::lacroix_palette('Orange', 6))) +
  theme(legend.position = 'none') +
  labs(x = 'Index SE', y = 'Relative error of terminal\nyear recruitment')
ggsave('wfc_figs/rec_100.png', device = 'png', width = 8, height = 4, dpi = 500)

# Recruitment year 80  
ts |> 
  filter(year == 80) |>
  tidyr::pivot_wider(names_from = model_run, values_from = Recruit_0, 
                     id_cols = c(iteration, scenario)) |>
  mutate(are = abs((em-om)/om),
         rel_err = (em - om)/om) |> 
  group_by(scenario) |>
  ggplot() +
  geom_violin(aes(x = scenario, y = rel_err, fill = scenario)) +
  geom_hline(yintercept = 0, color = 'black') +
  scale_fill_manual(values = rev(LaCroixColoR::lacroix_palette('Orange', 6)), ) +
  theme(legend.position = 'none') +
  labs(x = 'Index SE', y = 'Relative error of\nyear 80 recruitment')
ggsave('wfc_figs/rec_80.png', device = 'png', width = 8, height = 4, dpi = 500)

# SSB time series
# dq_all <- bind_rows(free = dq, zero_sum = dq_zero_sum, .id = 'do_rec') |> 
dq_long <- dq |>
  tidyr::pivot_longer(Value.SSB:Value.lnSPB) |>
  tidyr::pivot_wider(names_from = model_run, values_from = value, 
                     id_cols = c(iteration, scenario, year, name)) |>
  filter(!is.na(em)) |>
  group_by(name, scenario, year) |>
  summarise(mare = mean(abs((em-om)/om)),
            mre = mean((em-om)/om))
mare_ts <- dq_long |>
  ggplot() +
  geom_rect(xmin = 100, xmax = 114, ymin = 0, ymax = 0.35, fill = 'gray90') +
  geom_line(aes(x = year, y = mare, col = scenario, group = paste(scenario)), linewidth = 2) +
  scale_color_manual(values = rev(LaCroixColoR::lacroix_palette('Orange', 6))) +
  labs(x = 'Year', color = 'Index SE') +
  NULL

mare_ts %+% filter(dq_long, name == 'Value.SSB') +
  geom_line(aes(x = year, y = mare, group = paste(scenario)), 
            col = 'white', linewidth = 2.5) +
  geom_rect(xmin = 100, xmax = 114, ymin = 0, ymax = 0.35, fill = 'gray90') +
  ylab('Mean absolute relative error(SSB)') +
  geom_rect(xmin = 100, xmax = 114, ymin = 0, ymax = 0.35, fill = 'gray90')
ggsave('wfc_figs/ssb_mare1.png', device = 'png', width = 8, height = 4, dpi = 500)

mare_ts %+% filter(dq_long, name == 'Value.SSB') +
  ylab('Mean absolute relative error(SSB)') +
  geom_rect(xmin = 100, xmax = 114, ymin = 0, ymax = 0.35, fill = 'gray90') 
ggsave('wfc_figs/ssb_mare2.png', device = 'png', width = 8, height = 4, dpi = 500)

mare_ts %+% filter(dq_long, name == 'Value.SSB') +
  ylab('Mean absolute relative error(SSB)') 
ggsave('wfc_figs/ssb_mare3.png', device = 'png', width = 8, height = 4, dpi = 500)

mre_ts <- dq_long |>
  ggplot() +
  geom_rect(xmin = 100, xmax = 114, ymin = -0.035, ymax = 0.35, fill = 'gray90') +
  geom_line(aes(x = year, y = mre, col = scenario, group = paste(scenario)), linewidth = 2) +
  scale_color_manual(values = rev(LaCroixColoR::lacroix_palette('Orange', 6))) +
  geom_hline(yintercept = 0) +
  labs(x = 'Year', color = 'Index SE') +
  NULL

mre_ts %+% filter(dq_long, name == 'Value.SSB') +
  ylab('Mean relative error(SSB)')
ggsave('wfc_figs/ssb_mre.png', device = 'png', width = 8, height = 4, dpi = 500)

mre_ts %+% filter(dq_all,  name == 'Value.Bratio') +
  ylab('Mean relative error(Depletion)')

scalar |> 
  tidyr::pivot_wider(names_from = model_run, values_from = Recr_Unfished, 
                     id_cols = c(iteration, scenario)) |>
  mutate(are = abs((em-om)/om),
         rel_err = (em - om)/om) |> 
  group_by(scenario) |>
  ggplot() +
  geom_violin(aes(x = scenario, y = rel_err, fill = scenario)) +
  geom_hline(yintercept = 0, color = 'black') +
  scale_fill_manual(values = rev(LaCroixColoR::lacroix_palette('Orange', 6))) +
  theme(legend.position = 'none') +
  labs(x = 'Index SE', y = 'Relative error of terminal\nyear recruitment')

dq |>
  filter(model_run == 'em' | scenario == 'No index') |>
  mutate(Model = factor(ifelse(model_run == 'om', 'Oper. mod.', scenario))) |>
  mutate(Model = forcats::fct_rev(Model)) |>
  group_by(Model, year) |>
  summarise(SpawnBio = mean(Value.Bratio)) |>
  ggplot() +
  geom_line(aes(x = year, y = SpawnBio, col = Model, lty = Model, alpha = Model), 
            linewidth = 1) +
  scale_color_manual(values = c('gray50', LaCroixColoR::lacroix_palette('Orange', 6))) +
  labs(x = 'Year', y = 'Spawning Biomass') +
  # scale_y_continuous(labels = NULL) +
  scale_linetype_manual(values = lty_vec) +
  scale_alpha_manual(values = rep(1, 7))

scalar |> 
  tidyr::pivot_wider(names_from = model_run, values_from = Recr_Unfished, 
                     id_cols = c(iteration, scenario)) |>
  mutate(are = abs((em-om)/om),
         rel_err = (em - om)/om) |> 
  group_by(scenario) |>
  ggplot() +
  geom_violin(aes(x = scenario, y = rel_err, fill = scenario)) +
  geom_hline(yintercept = 0, color = 'black') +
  scale_fill_manual(values = rev(LaCroixColoR::lacroix_palette('Orange', 6)), ) +
  theme(legend.position = 'none') +
  labs(x = 'Index SE', y = 'Relative error of unfished recruitment')
ggsave('wfc_figs/r0.png', device = 'png', width = 8, height = 4, dpi = 500)


# Empirical petrale results -----------------------------------------------
file.copy(exe_loc, 'inst/extdata/models/petrale/klo_env_runs')
out1 <- SS_output('inst/extdata/models/petrale/klo_env_runs/est_q')
copy_SS_inputs('inst/extdata/models/petrale/klo_env_runs/est_q', 'inst/extdata/models/petrale/klo_env_runs/est_q_bias_adj')
SS_fitbiasramp(out1, oldctl = 'inst/extdata/models/petrale/klo_env_runs/est_q_bias_adj/petrale_control.ss',
               newctl = 'inst/extdata/models/petrale/klo_env_runs/est_q_bias_adj/petrale_control.ss')

copy_SS_inputs('inst/extdata/models/petrale/klo_env_runs/est_q_10yr', 'inst/extdata/models/petrale/klo_env_runs/est_q_10yr_bias_adj')
SS_fitbiasramp(out1, oldctl = 'inst/extdata/models/petrale/klo_env_runs/est_q_10yr_bias_adj/petrale_control.ss',
               newctl = 'inst/extdata/models/petrale/klo_env_runs/est_q_10yr_bias_adj/petrale_control.ss')


dirs <- sapply(c('production', 'klo_env_runs/est_q_bias_adj', 'klo_env_runs/est_q_10yr_bias_adj'),
               \(x) file.path('inst/extdata/models/petrale', x)) |>
  `names<-`(NULL) %>%
  r4ss::SSgetoutput(dirvec = ., getcovar = FALSE, getcomp = FALSE, verbose = FALSE) |>
  r4ss::SSsummarize()

SStableComparisons(out, modelnames = c('base', 'env', 'env_10yr'), 
                   names = c("Recr_Virgin", "R0", "NatM", "L_at_Amax", "VonBert_K", "SSB_Virg", 
                             "Bratio_2023", "SPRratio_2022", "OFLCatch_2023")) |>
  write.csv('inst/extdata/models/petrale/klo_env_runs/comparison_table.csv', row.names = FALSE)

ssb <- out$SpawnBio |>
  rename(Base = replist1, Env = replist2, Env_10yr = replist3) |>
  tidyr::pivot_longer(cols = Base:Env_10yr, names_to = 'Model', values_to = 'value') |>
  ggplot() +
  geom_rect(aes(ymax = max(value)), xmin = 2022.5, xmax = 2034, ymin = 0, fill = 'gray90') +
  geom_line(aes(x = Yr, y = value, col = Model), linewidth = 1) +
  labs(x = 'Year', y = 'Spawning Output') +
  theme(legend.position = 'none') +
  scale_color_manual(values = inauguration::inauguration('inauguration_2021', n = 3))

depl <- out$Bratio |>
  rename(Base = replist1, Env = replist2, Env_10yr = replist3) |>
  tidyr::pivot_longer(cols = Base:Env_10yr, names_to = 'Model', values_to = 'value') |>
  ggplot() +
  geom_rect(aes(ymax = max(value)), xmin = 2022.5, xmax = 2034, ymin = 0, fill = 'gray90') +
  geom_line(aes(x = Yr, y = value, col = Model), linewidth = 1) +
  labs(x = 'Year', y = 'Spawning Depletion') +
  scale_color_manual(values = inauguration::inauguration('inauguration_2021', n = 3))

recdev <- out$recdevs |>
  rename(Base = replist1, Env = replist2, Env_10yr = replist3) |>
  tidyr::pivot_longer(cols = Base:Env_10yr, names_to = 'Model', values_to = 'value') |>
  filter(grepl('Main', Label) | grepl('Late', Label)) |>
  ggplot() +
  geom_rect(aes(ymax = max(value), ymin = min(value)), xmin = 1992.5, xmax = 2022, fill = 'gray90', col = 'black') +
  geom_rect(aes(ymax = max(value), ymin = min(value)), xmin = 2012.5, xmax = 2022, fill = 'gray70', col = 'black') +
  geom_line(aes(x = Yr, y = value, col = Model), linewidth = 1) +
  labs(x = 'Year', y = 'Recruitment Deviation') +
  scale_color_manual(values = inauguration::inauguration('inauguration_2021', n = 3)) +
  theme(legend.position = 'none')

recruit <- out$recruits |>
  rename(Base = replist1, Env = replist2, Env_10yr = replist3) |>
  tidyr::pivot_longer(cols = Base:Env_10yr, names_to = 'Model', values_to = 'value') |>
  filter(Yr %in% 1959:2022) |>
  ggplot() +
  geom_rect(aes(ymax = max(value), ymin = min(value)), xmin = 1992.5, xmax = 2022, fill = 'gray90', col = 'black') +
  geom_rect(aes(ymax = max(value), ymin = min(value)), xmin = 2012.5, xmax = 2022, fill = 'gray70', col = 'black') +
  geom_line(aes(x = Yr, y = value, col = Model), linewidth = 1) +
  labs(x = 'Year', y = 'Recruitment') +
  scale_color_manual(values = inauguration::inauguration('inauguration_2021', n = 3))



gridExtra::grid.arrange(ssb, depl, nrow = 1, widths = c(0.42, 0.58)) |>
  ggsave(filename = 'inst/extdata/models/petrale/klo_env_runs/timeseries.png', device = 'png', width = 9, height = 4.5, units = 'in', dpi = 500)

gridExtra::grid.arrange(recdev, recruit, nrow = 1, widths = c(0.42, 0.58)) |>
  ggsave(filename = 'inst/extdata/models/petrale/klo_env_runs/recruitment.png', device = 'png', width = 9, height = 4.5, units = 'in', dpi = 500)
