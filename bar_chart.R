generate_bar_chart = function(shots) {
  
  ggplot() +
    
  theme(panel.border = element_blank(),
        panel.background = element_blank(),
        panel.grid.major = element_blank(),
        panel.grid.minor = element_blank(), 
        axis.line = element_line(colour = "black"),
        axis.text.y = element_text(size=15),
        legend.background = element_rect(fill = bg_color, color = bg_color),
        legend.position = "bottom",
        legend.key = element_blank(),
        legend.text = element_text(size = rel(1.0)))+
    
  geom_bar(data = shots,
           aes(x=shot_made_flag, fill = factor(shot_made_flag)),
           stat="count", 
           width=0.5)+
    
    scale_fill_manual(values = c("#FDE725", "#1F9D89"))+
    
    labs(list(x = "", y = "Number of Shots Taken", fill= ""))
}