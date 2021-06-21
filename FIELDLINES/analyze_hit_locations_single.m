function result = analyze_hit_locations_single(filename, l_more_plot, l_save, varargin)
% For analyzing the wall hit location after a FIELDLINES run
% For a single dataset
%
% WARNING
% Assumed that you used the w7x_divertor_op12b_fullres mesh (or accelerated versions)
% Analyzed the hit locations per divertor and checks distance from pumping
% gap

% Inputs:
% - filename: the file to load
% - l_more_plot: boolean to show more plots or not
% - l_save: boolean to save result to a save dir or not
% - varargin: you can put in what you want. If you have l_save enabled, the
% first other input needs to be the save location, 2nd the save location

% Make sure you have the file in the MATLAB path, this is a requirement of
% the read_fieldlines script

%   Created by: D.J. Engels (d.j.engels@student.tue.nl)
%   Version:    1.0
%   Date:       May 2021

%% initialize
if l_save
    % Check saving info
    if length(varargin) < 2
        error("Too few save arguments given")
    elseif length(varargin) > 2
        fprintf("Too many save arguments given. Will ignore everything after the 2nd\n");
    end
    dir_save = varargin{1};
    save_name = varargin{2};
    clear varargin
end

data = read_fieldlines(filename);

if class(data) ~= 'struct'
    fprintf("Cannot read data properly, canceling. Check if filename is correct.\n");
    result = struct();
    return
end
%% plot
if l_more_plot
    figure
    plot_fieldlines(data, 'wall_strike');
    xlabel('x (m)');ylabel('y (m)');zlabel('z (m)'); title('Hits per face');
    pause(0.001);
    
    figure;
    plot3(data.X_lines(:,2), data.Y_lines(:,2), data.Z_lines(:,2), 'o');
    xlabel('x (m)');ylabel('y (m)');zlabel('z (m)'); title('Hit locations');
end

%% Check incomplete lines
if sum(data.X_lines(:,3) == 0) > 0
    fprintf("Warning %d incomplete particle traces found\n", sum(data.X_lines(:,3) == 0));
else
    fprintf("Success, no incomplete particle traces!\n");
end

%% Run divertor heat load analysis
splits = 5;

% For each wall hit, get angle and distance
angle = atan2(data.Y_lines(:,2), data.X_lines(:,2));
angle(angle<-pi/splits) = angle(angle<-pi/splits)+2*pi;
angle(angle>2*pi - pi/splits) = angle(angle>2*pi - pi/splits)-2*pi;
dist = sqrt(data.Y_lines(:,2).^2 + data.X_lines(:,2).^2);

result = struct();
result.particle_load(splits) = struct();


if l_more_plot
    figure;
    hold on;
end

bool = false(length(data.Z_lines(:,2)), 1);
for i=1:splits
    lb = -pi/splits + (i-1)*2*pi/splits;
    ub = -pi/splits + i*2*pi/splits;
    upper_div = angle < ub & angle >= lb & data.Z_lines(:,2) >= 0;
    lower_div = angle < ub & angle >= lb & data.Z_lines(:,2) < 0;
    
    bool = bool | upper_div | lower_div;
    
    result.particle_load(i).lower_div = sum(lower_div);
    result.particle_load(i).upper_div = sum(upper_div);
    
    if l_more_plot
        title('Wall hits per divertor');
        plot3(data.X_lines(upper_div,2), data.Y_lines(upper_div,2), data.Z_lines(upper_div,2), 'o');
        plot3(data.X_lines(lower_div,2), data.Y_lines(lower_div,2), data.Z_lines(lower_div,2), 'o');
        xlabel('x (m)');ylabel('y (m)');zlabel('z (m)'); title('Hit locations');
    end
    
end

clear bool i lb splits ub lower_div upper_div
%% Calculate divertor result
tmp = struct();
tmp.upper_mean = mean([result.particle_load.upper_div]);
tmp.lower_mean = mean([result.particle_load.lower_div]);
tmp.upper_std = std([result.particle_load.upper_div]);
tmp.lower_std = std([result.particle_load.lower_div]);
tmp.upper_std_rel = tmp.upper_std / tmp.upper_mean;
tmp.lower_std_rel = tmp.lower_std / tmp.lower_mean;
tmp.upper_res = tmp.upper_std_rel;
tmp.lower_res = tmp.lower_std_rel;

result.particle_load_summary = tmp;

clear tmp
%% Plot divertor result
figure;hold off;
bar([result.particle_load.upper_div]);
names={'Div 1'; 'Div 2'; 'Div 3'; 'Div 4'; 'Div 5';};
set(gca,'xticklabel',names)
hold on;
bar(-[result.particle_load.lower_div]);
yline(result.particle_load_summary.upper_mean, '-', 'Mean (Upper)', 'LineWidth',3);
yline(-result.particle_load_summary.lower_mean, '-', 'Mean (Lower)', 'LineWidth',3);
ym = yline(mean([result.particle_load.upper_div, result.particle_load.lower_div]), '-', 'Mean', 'LineWidth',3);
ym2 = yline(-mean([result.particle_load.upper_div, result.particle_load.lower_div]), '-', 'Mean', 'LineWidth',3);
ym.LabelHorizontalAlignment = 'left';
ym.Color = [1 0 0];
ym2.LabelHorizontalAlignment = 'left';
ym2.Color = [1 0 0];
title('FLD hits per divertor'); xlabel('Divertor Nr.'); ylabel({'Hits (-)';'Positive: upper. Negative: lower divertor'});
pause(0.001);

clear ym ym2 names
%% Analysis distance from pumping gap
% Fill in variables for upper divertor around 0 degrees, rest will be
% mirrored automatically
phi_start = 13;   % in degrees
phi_size = 2;  % in degrees
r_min = 4.95;
r_max = 5.4;
z_min = 0.9;
z_max = 1.05;

res = 100;

%% Run analysis distance from pumping gap
phi_start = phi_start/180*pi;   % in rad
phi_size = phi_size/180*pi;  % in rad

if l_more_plot
    figure;
    plot_fieldlines(data, 'wall_strike');
    xlabel('x (m)');ylabel('y (m)');zlabel('z (m)'); title('Hits per face');
    %     figure;plot3(data.X_lines(:,2), data.Y_lines(:,2), data.Z_lines(:,2), 'o'); xlabel('x (m)');ylabel('y (m)');zlabel('z (m)')
    hold on;
end

% For each divertor
for i=1:5
    % First make boolean of hits in upper divertor
    phi_min = phi_start + (i-1)*pi/2.5;
    
    % plot box if wanted
    if l_more_plot
        phi = linspace(phi_min, phi_min+phi_size, res);
        [x_inner,y_inner] = pol2cart(phi,r_min.*ones(1,res));
        [x_outer,y_outer] = pol2cart(phi,r_max.*ones(1,res));
        
        [x_left,y_left] = pol2cart(phi_min.*ones(1,res),linspace(r_min, r_max, res));
        [x_right,y_right] = pol2cart((phi_min+phi_size).*ones(1,res),linspace(r_min, r_max, res));
        z_move = linspace(z_min, z_max, res);
        
        x_bounds = [x_inner(1).*ones(1,res), x_inner, x_right(1).*ones(1,res), x_right, fliplr(x_outer), fliplr(x_left), x_inner, x_right, x_right(end).*ones(1,res), fliplr(x_outer), x_outer(1).*ones(1,res), fliplr(x_left), x_inner, x_right];
        y_bounds = [y_inner(1).*ones(1,res), y_inner, y_right(1).*ones(1,res), y_right, fliplr(y_outer), fliplr(y_left), y_inner, y_right, y_right(end).*ones(1,res), fliplr(y_outer), y_outer(1).*ones(1,res), fliplr(y_left), y_inner, y_right];
        z_bounds = [z_move, z_max.*ones(1,res*1), z_move, z_max.*ones(1,res*5), fliplr(z_move), z_min.*ones(1,res), fliplr(z_move), z_min.*ones(1,res*3)];
        plot3(x_bounds, y_bounds, z_bounds);
    end
    
    upper_div = angle < phi_min + phi_size & angle >= phi_min ...
        & data.Z_lines(:,2) >= z_min & data.Z_lines(:,2) < z_max ...
        & dist >= r_min & dist < r_max;
    
    % Then boolean of hits in lower divertor
    phi_min = (i-1)*pi/2.5 - phi_start;
    lower_div = angle >= phi_min - phi_size & angle < phi_min ...
        & data.Z_lines(:,2) < -z_min & data.Z_lines(:,2) >= -z_max ...
        & dist >= r_min & dist < r_max;
    
    % Plot if wanted
    if l_more_plot
        phi = linspace(phi_min, phi_min-phi_size, res);
        [x_inner,y_inner] = pol2cart(phi,r_min.*ones(1,res));
        [x_outer,y_outer] = pol2cart(phi,r_max.*ones(1,res));
        
        [x_left,y_left] = pol2cart(phi_min.*ones(1,res),linspace(r_min, r_max, res));
        [x_right,y_right] = pol2cart((phi_min-phi_size).*ones(1,res),linspace(r_min, r_max, res));
        z_move = linspace(-z_min, -z_max, res);
        
        x_bounds = [x_inner(1).*ones(1,res), x_inner, x_right(1).*ones(1,res), x_right, fliplr(x_outer), fliplr(x_left), x_inner, x_right, x_right(end).*ones(1,res), fliplr(x_outer), x_outer(1).*ones(1,res), fliplr(x_left), x_inner, x_right];
        y_bounds = [y_inner(1).*ones(1,res), y_inner, y_right(1).*ones(1,res), y_right, fliplr(y_outer), fliplr(y_left), y_inner, y_right, y_right(end).*ones(1,res), fliplr(y_outer), y_outer(1).*ones(1,res), fliplr(y_left), y_inner, y_right];
        z_bounds = [z_move, -z_max.*ones(1,res*1), z_move, -z_max.*ones(1,res*5), fliplr(z_move), -z_min.*ones(1,res), fliplr(z_move), -z_min.*ones(1,res*3)];
        plot3(x_bounds, y_bounds, z_bounds);
    end
    
    % Find hits in box
    upper_hits = [data.X_lines(upper_div, 2), data.Y_lines(upper_div, 2), data.Z_lines(upper_div, 2)];
    lower_hits = [data.X_lines(lower_div, 2), data.Y_lines(lower_div, 2), data.Z_lines(lower_div, 2)];
    
    result.hit_locations(i).upper_div = upper_hits;
    result.hit_locations(i).lower_div = lower_hits;
    
    % Save distances from pumping gap for each divertor
    result.hit_from_gap(i).upper_div = dist(upper_div) - r_min;
    result.hit_from_gap(i).lower_div = dist(lower_div) - r_min;
end

clear r_min r_max z_min z_max phi_start phi_size phi_min res phi
clear x_bounds x_inner x_left x_outer x_right
clear y_bounds y_inner y_left y_outer y_right
clear z_bounds z_move
clear upper_div lower_div i upper_hits lower_hits
%% plot variance in hit from gap
colors = {[1 0 0], [0, 0, 1], [1, 0, 1], [0, 1, 0], [0, 1, 1]};
upper_div_hits = {result.hit_from_gap.upper_div};
lower_div_hits = {result.hit_from_gap.lower_div};
max_upper = max(cat(1,result.hit_from_gap.upper_div));
max_lower = max(cat(1,result.hit_from_gap.lower_div));
n_bins = 150;
edge_upper = 0:max_upper/n_bins:max_upper;
edge_lower = 0:max_lower/n_bins:max_lower;
tmp = struct();
tmp.upper = struct();tmp.lower = struct();
for i=1:5
    upper_hits = upper_div_hits{i};
    
    tmp.upper(i).binned = histcounts(upper_hits, edge_upper);
    tmp.upper(i).binned_smooth = smooth(tmp.upper(i).binned, n_bins/10);
    
    lower_hits = lower_div_hits{i};
    tmp.lower(i).binned = histcounts(lower_hits, edge_lower);
    tmp.lower(i).binned_smooth = smooth(tmp.lower(i).binned, n_bins/10);
end

x_lower = conv2(edge_lower, [1 1]/2); x_lower = x_lower(2:end-1);
x_upper = conv2(edge_upper, [1 1]/2); x_upper = x_upper(2:end-1);

figure;
ax = tight_subplot(2,1, 0.2, [0.12, 0.08], [0.08, 0.04]);
title('Each line is different divertor. Binned in 100 bins');
axes(ax(1));
hold on;
for i=1:5
    plot(x_upper, tmp.upper(i).binned, 'Color', colors{i})
    plot(x_upper, tmp.upper(i).binned_smooth,'--', 'Color', colors{i})
end
title('Strike positions on upper divertor');
xlabel('Distance from pumping gap (m)'); ylabel ('Hit Occurance (-)')
xlim([0, 0.35])
xticks(0:0.05:0.35)
xticklabels({'0', '0.05', '0.10', '0.15', '0.20', '0.25', '0.30', '0.35'})
yticks(0:20:200)
yticklabels({'0', '20', '40', '60', '80', '100', '120', '140', '160', '180', '200'})
axes(ax(2));
hold on;
for i=1:5
    plot(x_lower, tmp.lower(i).binned, 'Color', colors{i})
    plot(x_upper, tmp.lower(i).binned_smooth,'--', 'Color', colors{i})
end
title('Strike positions on lower divertor');
xlabel('Distance from pumping gap (m)'); ylabel ('Hit Occurance (-)')
xlim([0, 0.35])
xticks(0:0.05:0.35)
xticklabels({'0', '0.05', '0.10', '0.15', '0.20', '0.25', '0.30', '0.35'})
yticks(0:20:200)
yticklabels({'0', '20', '40', '60', '80', '100', '120', '140', '160', '180', '200'})
hold off;

clear n_bins max_lower max_upper lower_hits upper_hits upper_div_hits lower_div_hits
clear edge_lower eddge_upper colors
%% Create summary hit from gap
tmp2 = struct();
upper_peaks = zeros(1,5);
lower_peaks = zeros(1,5);

for i=1:5
    [~, max_ind] = max([tmp.upper(i).binned_smooth]);
    upper_peaks(i) = x_upper(max_ind);
    [~, max_ind] = max([tmp.upper(i).binned_smooth]);
    lower_peaks(i) = x_lower(max_ind);
end

tmp2.upper_mean = mean(upper_peaks);
tmp2.lower_mean = mean(lower_peaks);
tmp2.upper_std = std(upper_peaks);
tmp2.lower_std = std(lower_peaks);
tmp2.upper_std_rel = tmp2.upper_std / tmp2.upper_mean;
tmp2.lower_std_rel = tmp2.lower_std / tmp2.lower_mean;
tmp2.upper_res = tmp2.upper_std;
tmp2.lower_res = tmp2.lower_std;
tmp2.upper_resolution = mean(diff(x_upper));
tmp2.lower_resolution = mean(diff(x_lower));

result.hit_from_gap_summary = tmp2;

clear tmp tmp2 x_lower x_upper upper_peaks lower_peaks max_ind i
%% save result
if l_save
    save(strcat(dir_save, save_name, '.mat'), 'result');
end