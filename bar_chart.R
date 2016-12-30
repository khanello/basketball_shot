generate_bar_chart = function(shots) {
  ggplot(
    data = shots,
    aes(factor(shot_made_flag))) + 
  geom_bar(stat = "count")
}