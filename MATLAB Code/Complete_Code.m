%% Roll-axis b-sweep — Project 13
clear; clc;

modelName = 'roll';   % <-- replace with your .slx filename (no extension)
open_system(modelName);

% Block path to your damping gain block (the "b" triangle gain in your closed-loop subsystem)
% Right-click the block -> "Copy path to clipboard" gets you this exact string
bBlockPath = [modelName '/b/'];   % <-- replace with your actual path

% Values to sweep

bValues = [0.001, 0.005, 0.0154, 0.03, 0.1, 1];

% Table to collect results
results = table('Size',[length(bValues) 5], ...
    'VariableTypes', {'double','double','double','double','double'}, ...
    'VariableNames', {'b','RiseTime','SettlingTime','Overshoot','Peak'});

for i = 1:length(bValues)
    b_current = bValues(i);
    
    % Push this b value into the gain block
    set_param(bBlockPath, 'Gain', num2str(b_current));
    
    % Run the simulation
    simOut = sim(modelName);
    
    
    y = simOut.y_closed_loop.Data;
    t = simOut.y_closed_loop.Time;
    
    info = stepinfo(y, t);
    
    results.b(i)            = b_current;
    results.RiseTime(i)      = info.RiseTime;
    results.SettlingTime(i)  = info.SettlingTime;
    results.Overshoot(i)     = info.Overshoot;
    results.Peak(i)          = info.Peak;
    
    fprintf('b = %.4f done — RiseTime: %.3f, Settling: %.3f, Overshoot: %.2f%%\n', ...
        b_current, info.RiseTime, info.SettlingTime, info.Overshoot);
   
end

disp(results)


% Quick visual: overshoot and settling time vs b
figure;
subplot(2,1,1)
semilogx(results.b, results.Overshoot, '-o', 'LineWidth', 2)
xlabel('b'); ylabel('Overshoot (%)'); grid on; title('Overshoot vs Damping')

subplot(2,1,2)
semilogx(results.b, results.SettlingTime, '-o', 'LineWidth', 2)
xlabel('b'); ylabel('Settling Time (s)'); grid on; title('Settling Time vs Damping')

how i am using this code 


%% Project 13: Sanity Check Automation (Roll, Pitch, Yaw Isolated 5-deg Steps)
clear; close all;


modelName = 'Coupling'; % <-- UPDATE THIS to your exact Simulink model name

if ~bdIsLoaded(modelName)
    load_system(modelName);
end

% Set simulation duration
set_param(modelName, 'StopTime', '0.2');

% 5 degrees step amplitude in radians
cmd_5deg = deg2rad(57.3); % ~0.087266 rad

% Table to collect sanity check performance metrics
tests = {'Roll_Only', 'Pitch_Only', 'Yaw_Only'};
metricsTable = table('Size', [3, 7], ...
    'VariableTypes', {'string', 'double', 'double', 'double', 'double', 'double', 'double'}, ...
    'VariableNames', {'Test_Axis', 'RiseTime_s', 'SettlingTime_s', 'SettlingMin', 'SettlingMax', 'Overshoot_pct', 'Peak'});

figure('Name', 'Sanity Check Isolated 57.3-deg Step Responses', 'Position', [100, 100, 1000, 600]);

for i = 1:length(tests)
    testName = tests{i};
    
    % Configure Step inputs
    switch testName
        case 'Roll_Only'
            set_param([modelName '/r_phi'],   'After', num2str(cmd_5deg), 'Time', '0');
            set_param([modelName '/r_theta'], 'After', '0',               'Time', '0');
            set_param([modelName '/r_psi'],   'After', '0',               'Time', '0');
            targetSignal = 'phi';
            
        case 'Pitch_Only'
            set_param([modelName '/r_phi'],   'After', '0',               'Time', '0');
            set_param([modelName '/r_theta'], 'After', num2str(cmd_5deg), 'Time', '0');
            set_param([modelName '/r_psi'],   'After', '0',               'Time', '0');
            targetSignal = 'theta';
            
        case 'Yaw_Only'
            set_param([modelName '/r_phi'],   'After', '0',               'Time', '0');
            set_param([modelName '/r_theta'], 'After', '0',               'Time', '0');
            set_param([modelName '/r_psi'],   'After', num2str(cmd_5deg), 'Time', '0');
            targetSignal = 'psi';
    end
    
    % Run simulation
    simOut = sim(modelName);
    
    % Extract primary response
    sigData = simOut.(targetSignal).Data;
    t = simOut.(targetSignal).Time;
    
    % Compute step performance characteristics
    info = stepinfo(sigData, t, cmd_5deg);
    
    metricsTable.Test_Axis(i)      = testName;
    metricsTable.RiseTime_s(i)     = info.RiseTime;
    metricsTable.SettlingTime_s(i) = info.SettlingTime;
    metricsTable.SettlingMin(i)    = info.SettlingMin;
    metricsTable.SettlingMax(i)    = info.SettlingMax;
    metricsTable.Overshoot_pct(i)  = info.Overshoot;
    metricsTable.Peak(i)           = info.Peak;
    
    % Plot 3-axis tracking
    subplot(3, 1, i);
    plot(t, rad2deg(simOut.phi.Data), 'r', 'LineWidth', 1.5); hold on;
    plot(t, rad2deg(simOut.theta.Data), 'g', 'LineWidth', 1.5);
    plot(t, rad2deg(simOut.psi.Data), 'b', 'LineWidth', 1.5);
    yline(5, '--k', 'Command (57.3 deg)');
    grid on;
    ylabel('Angle (deg)');
    title([strrep(testName, '_', ' ') ' Step Response']);
    legend('\phi (Roll)', '\theta (Pitch)', '\psi (Yaw)', 'Location', 'SouthEast');
end

xlabel('Time (s)');

fprintf('\n================== SANITY CHECK METRICS TABLE (57.3-DEG STEPS) ==================\n');
disp(metricsTable);

%% Project 13: Simultaneous 3-Axis Multi-Amplitude Coupled Test 

modelName = 'Coupling'; % Replace with your exact model name
if ~bdIsLoaded(modelName), load_system(modelName); end
set_param(modelName, 'StopTime', '0.2');
amplitudes_deg = [5, 10, 57.3];
amplitudes_rad = deg2rad(amplitudes_deg);
figure('Name', 'Simultaneous 3-Axis Step Response Across Amplitudes', 'Position', [100, 100, 1100, 700]);
simResults = table();
for k = 1:length(amplitudes_rad)
    amp = amplitudes_rad(k);
    amp_deg = amplitudes_deg(k);
    
    % Apply simultaneous step commands to ALL three axes at t = 0
    set_param([modelName '/r_phi'],   'After', num2str(amp), 'Time', '0');
    set_param([modelName '/r_theta'], 'After', num2str(amp), 'Time', '0');
    set_param([modelName '/r_psi'],   'After', num2str(amp), 'Time', '0');
    
    simOut = sim(modelName);
    
    t = simOut.phi.Time;
    phi = simOut.phi.Data;
    theta = simOut.theta.Data;
    psi = simOut.psi.Data;
    
    info_phi   = stepinfo(phi, t, amp);
    info_theta = stepinfo(theta, t, amp);
    info_psi   = stepinfo(psi, t, amp);
    
    % Store table row
    row = table(amp_deg, ...
        info_phi.RiseTime, info_phi.SettlingTime, info_phi.Overshoot, ...
        info_theta.RiseTime, info_theta.SettlingTime, info_theta.Overshoot, ...
        info_psi.RiseTime, info_psi.SettlingTime, info_psi.Overshoot, ...
        'VariableNames', {'Amp_deg', ...
        'Roll_tr', 'Roll_ts', 'Roll_OS', ...
        'Pitch_tr', 'Pitch_ts', 'Pitch_OS', ...
        'Yaw_tr', 'Yaw_ts', 'Yaw_OS'});
    
    simResults = [simResults; row];
    
    % Plot response curves
    subplot(3, 1, k);
    plot(t, rad2deg(phi), 'r', 'LineWidth', 1.5); hold on;
    plot(t, rad2deg(theta), 'g', 'LineWidth', 1.5);
    plot(t, rad2deg(psi), 'b', 'LineWidth', 1.5);
    yline(amp_deg, '--k', sprintf('Command (%.1f deg)', amp_deg));
    grid on;
    ylabel('Angle (deg)');
    title(sprintf('Simultaneous %.1f^\\circ Step (Roll, Pitch, Yaw Active)', amp_deg));
    legend('\phi (Roll)', '\theta (Pitch)', '\psi (Yaw)', 'Location', 'SouthEast');
end
xlabel('Time (s)');
fprintf('\n================== SIMULTANEOUS 3-AXIS PERFORMANCE TABLE ==================\n');
disp(simResults);


%% Phase 5B — RMSE Analysis: True vs. Measured States (To Workspace blocks)
clear; clc;

modelName = 'Sensor_Model';   % <-- replace with your actual .slx filename
open_system(modelName);

sim(modelName);   % To Workspace blocks write directly into the base workspace

% Match these to the EXACT "Variable name" you set in each To Workspace block
trueVarNames = {'phi', 'theta', 'psi', 'p', 'q', 'r'};
measVarNames = {'phi_meas', 'theta_meas', 'psi_meas', 'p_meas', 'q_meas', 'r_meas'};
labels       = {'phi', 'theta', 'psi', 'p', 'q', 'r'};
units        = {'rad', 'rad', 'rad', 'rad/s', 'rad/s', 'rad/s'};

results = table('Size', [6 5], ...
    'VariableTypes', {'string','double','double','double','double'}, ...
    'VariableNames', {'Signal','RMSE','PeakTrueValue','RMSE_pct_of_peak','NoiseSTD'});

figure('Name','True vs Measured — All Channels','Position',[100 100 1200 800]);

for i = 1:6
    trueStruct = eval(trueVarNames{i});   % pulls the variable by name from base workspace
    measStruct = eval(measVarNames{i});
    
    t_true = trueStruct.Time;
    y_true = trueStruct.Data;
    t_meas = measStruct.Time;
    y_meas = measStruct.Data;
    
    % Interpolate measured onto true's time vector in case sample times differ
    y_meas_interp = interp1(t_meas, y_meas, t_true, 'linear', 'extrap');
    
    err = y_true - y_meas_interp;
    rmse = sqrt(mean(err.^2));
    peakVal = max(abs(y_true));
    rmse_pct = 100 * rmse / peakVal;
    noiseSTD = std(err);
    
    results.Signal(i)          = labels{i};
    results.RMSE(i)             = rmse;
    results.PeakTrueValue(i)    = peakVal;
    results.RMSE_pct_of_peak(i) = rmse_pct;
    results.NoiseSTD(i)         = noiseSTD;
    
    subplot(3,2,i);
    plot(t_true, y_true, 'r', 'LineWidth', 1.5); hold on;
    plot(t_true, y_meas_interp, 'b');
    grid on;
    title(sprintf('%s (RMSE = %.4g %s, %.2f%% of peak)', labels{i}, rmse, units{i}, rmse_pct));
    legend(labels{i}, [labels{i} '\_meas'], 'Location', 'best');
    xlabel('Time (s)'); ylabel(units{i});
end

fprintf('\n================== RMSE SUMMARY — TRUE vs MEASURED ==================\n');
disp(results)




%% Pitch Kalman Filter Design
I_pitch = 2.76e-5;
b_crit_pitch = 0.0105;
Ts = 0.001;

A_p = [0 1; 0 -b_crit_pitch/I_pitch];
B_p = [0; 1/I_pitch];
C_p = [1 0; 0 1];
D_p = [0; 0];

sys_pitch_d = c2d(ss(A_p,B_p,C_p,D_p), Ts);

Ad_pitch = sys_pitch_d.A;
Cd_pitch = sys_pitch_d.C;
Bd_pitch = sys_pitch_d.B;

R_pitch = diag([0.026881^2, 0.038771^2]);   % theta, q noise std from your Phase 5B table
Q_pitch = diag([0.01, 0.01]) ;              % same starting point as roll

[~, K_pitch, ~] = dlqe(Ad_pitch, eye(2), Cd_pitch, Q_pitch, R_pitch);

A_cl_pitch = (eye(2) - K_pitch*Cd_pitch) * Ad_pitch;
disp('K_pitch:'); disp(K_pitch)
disp('Pole magnitudes:'); disp(abs(eig(A_cl_pitch)))


%% Kalman Filter for roll and roll rate


b_crtitial_roll = 0.0154;
I_roll = 5.94e-5;

A = [0 1 ; 0 -b_crtitial_roll/I_roll] ;       

B = [0 ; 1/I_roll];

C = [1 0;0 1];

D = [0;0];

sys_roll = ss(A,B,C,D);

% Continuous to Discrete Time 

Ts = 0.001;

sys_roll_d = c2d(sys_roll,Ts);

Ad_roll = sys_roll_d.A;
Bd_roll = sys_roll_d.B;
Cd_roll = sys_roll_d.C;
Dd = sys_roll_d.D;


Q = diag([0.01, 0.8]);

R = diag([0.0268^2, 0.0436^2]);  

[~,K_roll,~] = dlqe(Ad_roll,eye(2),Cd_roll,Q,R);

A_cl = (eye(2) - K_roll*Cd_roll) * Ad_roll;
disp('K_roll:'); disp(K_roll)
disp('Pole magnitudes:'); disp(abs(eig(A_cl)))


%% Yaw Kalman Filter Design
I_yaw = 8.70e-5;
b_crit_yaw = 0.0187;
Ts = 0.001;

A_y = [0 1; 0 -b_crit_yaw/I_yaw];
B_y = [0; 1/I_yaw];
C_y = [1 0; 0 1];
D_y = [0; 0];

sys_yaw_d = c2d(ss(A_y,B_y,C_y,D_y), Ts);
Ad_yaw = sys_yaw_d.A;
Cd_yaw = sys_yaw_d.C;
Bd_yaw = sys_yaw_d.B;

R_yaw = diag([0.026575^2, 0.040843^2]);   % psi, r noise std from your Phase 5B table
Q_yaw = diag([0.01, 0.8])

[~, K_yaw, ~] = dlqe(Ad_yaw, eye(2), Cd_yaw, Q_yaw, R_yaw);
A_cl_yaw = (eye(2) - K_yaw*Cd_yaw) * Ad_yaw;
disp('K_yaw:'); disp(K_yaw)
disp('Pole magnitudes:'); disp(abs(eig(A_cl_yaw)))

%% Phase 5D — Closed-Loop Performance: True State vs Estimated State vs Reference



modelName = 'Kalman_Filter_6_states';  
open_system(modelName);
sim(modelName);

trueVarNames = {'phi', 'theta', 'psi', 'p', 'q', 'r'};
estVarNames  = {'phi_est', 'theta_est', 'psi_est', 'p_est', 'q_est', 'r_est'};
labels       = {'phi', 'theta', 'psi', 'p', 'q', 'r'};
units        = {'rad', 'rad', 'rad', 'rad/s', 'rad/s', 'rad/s'};


commanded    = [true, false, false, true, false, false];   % phi & p are roll's angle/rate
refAmplitude = [deg2rad(5), 0, 0, NaN, 0, 0];  % rate axes don't have a "reference angle" — see note below

results = table('Size', [6 6], ...
    'VariableTypes', {'string','double','double','double','double','double'}, ...
    'VariableNames', {'Signal','Commanded','RiseTime_or_NaN','SettlingTime_or_NaN', ...
                       'Overshoot_or_NaN','RMS_chatter_or_SSError'});

figure('Name','True vs Estimated State — Closed Loop (Phase 5D, fixed)','Position',[100 100 1300 850]);

for i = 1:6
    trueData = evalin('base', trueVarNames{i});
    estData  = evalin('base', estVarNames{i});
    
    t = trueData.Time;
    y_true = trueData.Data(:);
    y_est_interp = interp1(estData.Time, estData.Data(:), t, 'linear', 'extrap');
    
    results.Signal(i) = labels{i};
    results.Commanded(i) = commanded(i);
    
    if commanded(i) && ~isnan(refAmplitude(i)) && refAmplitude(i) ~= 0
        % Genuinely commanded axis with a real target angle — real stepinfo
        info = stepinfo(y_true, t, refAmplitude(i));
        results.RiseTime_or_NaN(i)     = info.RiseTime;
        results.SettlingTime_or_NaN(i) = info.SettlingTime;
        results.Overshoot_or_NaN(i)    = info.Overshoot;
        results.RMS_chatter_or_SSError(i) = abs(refAmplitude(i) - y_true(end));
    else
       
        results.RiseTime_or_NaN(i)     = NaN;
        results.SettlingTime_or_NaN(i) = NaN;
        results.Overshoot_or_NaN(i)    = NaN;
        results.RMS_chatter_or_SSError(i) = sqrt(mean(y_true.^2));
    end
    
    subplot(3,2,i);
    plot(t, y_true, 'k', 'LineWidth', 1.6); hold on;
    plot(t, y_est_interp, 'r--', 'LineWidth', 1.1);
    if commanded(i) && ~isnan(refAmplitude(i)) && refAmplitude(i) ~= 0
        yline(refAmplitude(i), ':b', 'Reference');
        ttl = sprintf('%s — commanded (RMSE true/est=%.4g)', labels{i}, sqrt(mean((y_true-y_est_interp).^2)));
    else
        yline(0, ':b', 'Zero ref');
        ttl = sprintf('%s — uncommanded, RMS chatter=%.4g', labels{i}, sqrt(mean(y_true.^2)));
    end
    grid on; title(ttl);
    legend(labels{i}, [labels{i} '\_est'], 'Location', 'best');
    xlabel('Time (s)'); ylabel(units{i});
end

fprintf('\n================== PHASE 5D CLOSED-LOOP PERFORMANCE (fixed) ==================\n');
disp(results)

%% Phase 6B — Pitch Disturbance Rejection Analysis (True-State Feedback)
clear; clc;

% 1. Simulation Setup
modelName = 'Single_Axis_Pitch_Disturbance';   
open_system(modelName);
sim(modelName);

data = y_closed_loop;
t = data.Time;
y = data.Data(:);

% 3. Disturbance & Reference Parameters
refValue = deg2rad(5);         % same 5° commanded angle
disturbanceStart = 0.07;       % pitch's onset, not roll's 0.1
disturbanceEnd = 0.0735;       % pitch's pulse end

% 4. Isolate the Post-Disturbance Window (t >= 0.1s)
idx_post = t >= disturbanceStart;
t_post   = t(idx_post);
y_post   = y(idx_post);

% 5. Peak Deviation (Maximum bump caused by torque pulse)
deviation        = y_post - refValue;
[maxDev, maxIdx] = max(abs(deviation));
peakTime         = t_post(maxIdx);
peakAngle        = y_post(maxIdx);

% 6. Recovery Time (2% Settling Band around Reference)
band         = 0.02 * refValue;   % +/- 2% of 5 deg (~0.1 deg)
recovered    = false;
recoveryTime = NaN;

for k = maxIdx:length(y_post)
    % Verify the trajectory enters and remains within the band indefinitely
    if all(abs(y_post(k:end) - refValue) <= band)
        recoveryTime = t_post(k) - disturbanceStart;
        recovered    = true;
        break;
    end
end

% 7. Display Key Metrics
fprintf('\n================== PHASE 6B — DISTURBANCE REJECTION ==================\n');
fprintf('Reference Target Angle         : %.5f rad (%.2f deg)\n', refValue, rad2deg(refValue));
fprintf('Peak Deviation from Target     : %.5f rad (%.3f deg)\n', maxDev, rad2deg(maxDev));
fprintf('Peak Deviation Percentage      : %.2f %% of reference\n', (maxDev / refValue) * 100);
fprintf('Time to Reach Peak Deviation   : %.4f s (after pulse onset)\n', peakTime - disturbanceStart);

if recovered
    fprintf('Recovery Time (to 2%% band)     : %.4f s (after pulse onset)\n', recoveryTime);
    fprintf('Total Settling Timestamp       : %.4f s\n', disturbanceStart + recoveryTime);
else
    fprintf('Recovery Time                  : System did NOT settle within 2%% band during simulation.\n');
end
fprintf('======================================================================\n');



figure('Name','Phase 6B: Pitch Disturbance Zoomed (Degrees)','Position',[150 150 950 520]);

% Convert to degrees
y_deg         = rad2deg(y);
refValue_deg  = rad2deg(refValue);
band_deg      = rad2deg(band);
maxDev_deg    = rad2deg(maxDev);
peakAngle_deg = rad2deg(peakAngle);

% Define tight zoom window around the pitch pulse (0.07s - 0.0735s)
t_zoom_start = 0.055;
t_zoom_end   = 0.110;
idx_zoom = (t >= t_zoom_start) & (t <= t_zoom_end);

% 1. Disturbance pulse shaded box (3.5 ms pulse)
patch([disturbanceStart disturbanceEnd disturbanceEnd disturbanceStart], ...
      [4.85 4.85 5.15 5.15], [1 0.85 0.95], 'EdgeColor', 'none', ...
      'FaceAlpha', 0.6, 'DisplayName', 'Disturbance Pulse (3.5ms)');
hold on;

% 2. ±2% Recovery Band
yline(refValue_deg + band_deg, ':r', 'LineWidth', 1.1, 'DisplayName', '\pm2% Recovery Band');
yline(refValue_deg - band_deg, ':r', 'LineWidth', 1.1, 'HandleVisibility', 'off');

% 3. Reference line (5 deg)
yline(refValue_deg, 'k--', 'LineWidth', 1.2, 'DisplayName', 'Reference (5^\circ)');

% 4. True Pitch Response
plot(t(idx_zoom), y_deg(idx_zoom), 'b', 'LineWidth', 2.0, 'DisplayName', 'True Pitch Angle \theta');

% 5. Peak deviation point
plot(peakTime, peakAngle_deg, 'ro', 'MarkerFaceColor', 'r', 'MarkerSize', 6, ...
     'DisplayName', sprintf('Peak Bump (+%.3f^\\circ)', maxDev_deg));

grid on;
xlim([t_zoom_start, t_zoom_end]);

% Y-axis headroom centered around the 5 deg setpoint
ylim([4.88, 5.03]);

xlabel('Time (s)', 'FontSize', 11);
ylabel('Pitch Angle \theta (^\circ)', 'FontSize', 11);
title(sprintf('Pitch Disturbance Rejection (Zoomed): Peak Bump = +%.3f^\\circ, Recovery Time = %.4fs', ...
      maxDev_deg, recoveryTime), 'FontSize', 12);

legend('Location', 'southeast', 'FontSize', 9);

%% Phase 6B — Roll Disturbance Rejection Analysis (True-State Feedback)
clear; clc;

% 1. Simulation Setup
modelName = 'Single_Axis_Roll_Disturbance';   % <-- Put your exact .slx file name here (without .slx)
open_system(modelName);
sim(modelName);

data = y_closed_loop;
t = data.Time;
y = data.Data(:);

% 3. Disturbance & Reference Parameters
refValue         = deg2rad(5);   % Commanded roll angle: 5 deg = 0.087266 rad
disturbanceStart = 0.100;        % Disturbance pulse onset (s)
disturbanceEnd   = 0.105;        % Disturbance pulse end (s)

% 4. Isolate the Post-Disturbance Window (t >= 0.1s)
idx_post = t >= disturbanceStart;
t_post   = t(idx_post);
y_post   = y(idx_post);

% 5. Peak Deviation (Maximum bump caused by torque pulse)
deviation        = y_post - refValue;
[maxDev, maxIdx] = max(abs(deviation));
peakTime         = t_post(maxIdx);
peakAngle        = y_post(maxIdx);

% 6. Recovery Time (2% Settling Band around Reference)
band         = 0.02 * refValue;   % +/- 2% of 5 deg (~0.1 deg)
recovered    = false;
recoveryTime = NaN;

for k = maxIdx:length(y_post)
    % Verify the trajectory enters and remains within the band indefinitely
    if all(abs(y_post(k:end) - refValue) <= band)
        recoveryTime = t_post(k) - disturbanceStart;
        recovered    = true;
        break;
    end
end

% 7. Display Key Metrics
fprintf('\n================== PHASE 6B — DISTURBANCE REJECTION ==================\n');
fprintf('Reference Target Angle         : %.5f rad (%.2f deg)\n', refValue, rad2deg(refValue));
fprintf('Peak Deviation from Target     : %.5f rad (%.3f deg)\n', maxDev, rad2deg(maxDev));
fprintf('Peak Deviation Percentage      : %.2f %% of reference\n', (maxDev / refValue) * 100);
fprintf('Time to Reach Peak Deviation   : %.4f s (after pulse onset)\n', peakTime - disturbanceStart);

if recovered
    fprintf('Recovery Time (to 2%% band)     : %.4f s (after pulse onset)\n', recoveryTime);
    fprintf('Total Settling Timestamp       : %.4f s\n', disturbanceStart + recoveryTime);
else
    fprintf('Recovery Time                  : System did NOT settle within 2%% band during simulation.\n');
end
fprintf('======================================================================\n');

% 8. Single Clean Disturbance Rejection Plot (Degrees on Y-Axis)
figure('Name','Phase 6B: Disturbance Rejection (Degrees)','Position',[150 150 950 520]);

% Convert radians to degrees for plotting
y_deg        = rad2deg(y);
refValue_deg = rad2deg(refValue);
band_deg     = rad2deg(band);
maxDev_deg   = rad2deg(maxDev);
peakAngle_deg= rad2deg(peakAngle);

% A. Subtle shaded region for the 5ms disturbance window
patch([disturbanceStart disturbanceEnd disturbanceEnd disturbanceStart], ...
      [0 0 7 7], [1 0.85 0.95], 'EdgeColor', 'none', ...
      'FaceAlpha', 0.6, 'DisplayName', 'Disturbance Pulse (5ms)');
hold on;

% B. Tolerance bounds (+/- 2% recovery band in degrees)
yline(refValue_deg + band_deg, ':r', 'LineWidth', 1.0, 'DisplayName', '\pm2% Recovery Band');
yline(refValue_deg - band_deg, ':r', 'LineWidth', 1.0, 'HandleVisibility', 'off');

% C. Reference setpoint (5 deg)
yline(refValue_deg, 'k--', 'LineWidth', 1.2, 'DisplayName', 'Reference (5^\circ)');

% D. True roll response in degrees
plot(t, y_deg, 'b', 'LineWidth', 1.8, 'DisplayName', 'True Roll Angle \phi');

% E. Peak deviation point in degrees
plot(peakTime, peakAngle_deg, 'ro', 'MarkerFaceColor', 'r', 'MarkerSize', 6, ...
     'DisplayName', sprintf('Peak Bump (+%.3f^\\circ)', maxDev_deg));

grid on;
xlim([0, 0.2]);
ylim([0, 6.5]);   % Headroom up to 6.5 degrees

xlabel('Time (s)', 'FontSize', 11);
ylabel('Roll Angle \phi (^\circ)', 'FontSize', 11);
title(sprintf('Roll Disturbance Rejection: Peak Bump = +%.3f^\\circ, Recovery Time = %.4fs', ...
      maxDev_deg, recoveryTime), 'FontSize', 12);

legend('Location', 'southeast', 'FontSize', 9);

%% Phase 6B — Yaw Disturbance Rejection Analysis (True-State Feedback)
clear; clc;

% 1. Simulation Setup
modelName = 'Single_Axis_Yaw_Disturbance';   
open_system(modelName);
sim(modelName);

data = y_closed_loop;
t = data.Time;
y = data.Data(:);

% 3. Disturbance & Reference Parameters
refValue = deg2rad(5);
disturbanceStart = 0.12;
disturbanceEnd = 0.1235;

% 4. Isolate the Post-Disturbance Window (t >= 0.1s)
idx_post = t >= disturbanceStart;
t_post   = t(idx_post);
y_post   = y(idx_post);

% 5. Peak Deviation (Maximum bump caused by torque pulse)
deviation        = y_post - refValue;
[maxDev, maxIdx] = max(abs(deviation));
peakTime         = t_post(maxIdx);
peakAngle        = y_post(maxIdx);

% 6. Recovery Time (2% Settling Band around Reference)
band         = 0.02 * refValue;   % +/- 2% of 5 deg (~0.1 deg)
recovered    = false;
recoveryTime = NaN;

for k = maxIdx:length(y_post)
    % Verify the trajectory enters and remains within the band indefinitely
    if all(abs(y_post(k:end) - refValue) <= band)
        recoveryTime = t_post(k) - disturbanceStart;
        recovered    = true;
        break;
    end
end

% 7. Display Key Metrics
fprintf('\n================== PHASE 6B — DISTURBANCE REJECTION ==================\n');
fprintf('Reference Target Angle         : %.5f rad (%.2f deg)\n', refValue, rad2deg(refValue));
fprintf('Peak Deviation from Target     : %.5f rad (%.3f deg)\n', maxDev, rad2deg(maxDev));
fprintf('Peak Deviation Percentage      : %.2f %% of reference\n', (maxDev / refValue) * 100);
fprintf('Time to Reach Peak Deviation   : %.4f s (after pulse onset)\n', peakTime - disturbanceStart);

if recovered
    fprintf('Recovery Time (to 2%% band)     : %.4f s (after pulse onset)\n', recoveryTime);
    fprintf('Total Settling Timestamp       : %.4f s\n', disturbanceStart + recoveryTime);
else
    fprintf('Recovery Time                  : System did NOT settle within 2%% band during simulation.\n');
end
fprintf('======================================================================\n');

%% Phase 6B — Yaw Disturbance Zoomed Plot
figure('Name','Phase 6B: Yaw Disturbance Zoomed (Degrees)','Position',[150 150 950 520]);

% Convert radians to degrees
y_deg         = rad2deg(y);
refValue_deg  = rad2deg(refValue);
band_deg      = rad2deg(band);
maxDev_deg    = rad2deg(maxDev);
peakAngle_deg = rad2deg(peakAngle);

% Zoom tightly around the pulse (0.090s - 0.098s)
t_zoom_start = 0.075;
t_zoom_end   = 0.135;
idx_zoom = (t >= t_zoom_start) & (t <= t_zoom_end);

% 1. Disturbance pulse shaded box (8ms duration: 0.090s to 0.098s)
patch([disturbanceStart disturbanceEnd disturbanceEnd disturbanceStart], ...
      [4.95 4.95 5.05 5.05], [1 0.85 0.95], 'EdgeColor', 'none', ...
      'FaceAlpha', 0.6, 'DisplayName', 'Disturbance Pulse (8ms)');
hold on;

% 2. +/- 2% Recovery Band (4.9 deg to 5.1 deg)
yline(refValue_deg + band_deg, ':r', 'LineWidth', 1.1, 'DisplayName', '\pm2% Recovery Band (\pm0.1^\circ)');
yline(refValue_deg - band_deg, ':r', 'LineWidth', 1.1, 'HandleVisibility', 'off');

% 3. Reference setpoint
yline(refValue_deg, 'k--', 'LineWidth', 1.2, 'DisplayName', 'Reference (5^\circ)');

% 4. True Yaw Angle
plot(t(idx_zoom), y_deg(idx_zoom), 'b', 'LineWidth', 2.0, 'DisplayName', 'True Yaw Angle \psi');

% 5. Peak deviation marker
plot(peakTime, peakAngle_deg, 'ro', 'MarkerFaceColor', 'r', 'MarkerSize', 6, ...
     'DisplayName', sprintf('Peak Bump (+%.4f^\\circ)', maxDev_deg));

grid on;
xlim([t_zoom_start, t_zoom_end]);

% Millidegree scale centered around 5 deg
ylim([4.970, 5.030]);

xlabel('Time (s)', 'FontSize', 11);
ylabel('Yaw Angle \psi (^\circ)', 'FontSize', 11);
title(sprintf('Yaw Disturbance Rejection (Zoomed): Peak Bump = +%.4f^\\circ (Never leaves \\pm2%% band)', ...
      maxDev_deg), 'FontSize', 12);

legend('Location', 'southeast', 'FontSize', 9);


%% Phase 6C — Pitch Disturbance Rejection Analysis (Kalman Feedback)
% 1. Simulation Setup
modelName = 'Single_Axis_Pitch_Disturbance_Est_Feedback';
open_system(modelName);
sim(modelName);

% 2. Extract True Pitch Angle
data = theta;
t = data.Time;
y = data.Data(:);

% 3. Disturbance & Reference Parameters
refValue         = deg2rad(5);   % 5 deg setpoint (0.08727 rad)
disturbanceStart = 0.100;        % Aligned at 0.10s to let pitch settle
disturbanceEnd   = 0.1035;       % 3.5ms pulse duration
band             = 0.02 * refValue; % 2% recovery band (+/-0.1 deg)

% 4. Transient Window (0.10s to 0.15s)
idx_transient = (t >= disturbanceStart) & (t <= 0.150);
t_trans       = t(idx_transient);
y_trans       = y(idx_transient);

% 5. Peak Upward Bump (Crest Detection)
dev_trans        = y_trans - refValue;
[maxDev, relIdx] = max(dev_trans);
peakTime         = t_trans(relIdx);
peakAngle        = y_trans(relIdx);

% 6. Steady-State Chatter Analysis (Post-Transient: 0.15s to 0.20s)
idx_ss          = t >= 0.150;
ss_error        = y(idx_ss) - refValue;
rms_chatter_rad = rms(ss_error);
rms_chatter_deg = rad2deg(rms_chatter_rad);
rms_chatter_pct = (rms_chatter_rad / refValue) * 100;

% 7. Degree Conversions for Plotting & Display
y_deg         = rad2deg(y);
refValue_deg  = rad2deg(refValue);
band_deg      = rad2deg(band);
maxDev_deg    = rad2deg(maxDev);
peakAngle_deg = rad2deg(peakAngle);

% 8. Display Key Metrics
fprintf('\n================== PHASE 6C — PITCH DISTURBANCE REJECTION ==================\n');
fprintf('Reference Target Angle         : %.5f rad (%.2f deg)\n', refValue, refValue_deg);
fprintf('True Peak Bump from Target     : %.5f rad (%.3f deg)\n', maxDev, maxDev_deg);
fprintf('Peak Bump Percentage           : %.2f %% of reference\n', (maxDev / refValue) * 100);
fprintf('Time of Peak Bump              : %.4f s (at t = %.4f s)\n', peakTime - disturbanceStart, peakTime);
fprintf('Steady-State RMS Chatter       : %.5f rad (%.3f deg, %.2f%% of ref)\n', ...
        rms_chatter_rad, rms_chatter_deg, rms_chatter_pct);
fprintf('Settling Status                : Persistent bounded chatter (does not enter quiet steady state)\n');
fprintf('===========================================================================\n');

% 9. Full Plot with Corrected Peak Marker
figure('Name','Phase 6C: Pitch Disturbance (Full Response)','Position',[150 150 950 520]);

% A. Disturbance pulse shaded region
patch([disturbanceStart disturbanceEnd disturbanceEnd disturbanceStart], ...
      [0 0 7 7], [1 0.85 0.95], 'EdgeColor', 'none', ...
      'FaceAlpha', 0.6, 'DisplayName', 'Disturbance Pulse (3.5ms)');
hold on;

% B. Reference and tolerance lines
yline(refValue_deg + band_deg, ':r', 'LineWidth', 1.0, 'DisplayName', '\pm2% Recovery Band');
yline(refValue_deg - band_deg, ':r', 'LineWidth', 1.0, 'HandleVisibility', 'off');
yline(refValue_deg, 'k--', 'LineWidth', 1.2, 'DisplayName', 'Reference (5^\circ)');

% C. True pitch trajectory
plot(t, y_deg, 'b', 'LineWidth', 1.6, 'DisplayName', 'True Pitch Angle \theta');

% D. Corrected Peak Marker
plot(peakTime, peakAngle_deg, 'ro', 'MarkerFaceColor', 'r', 'MarkerSize', 6, ...
     'DisplayName', sprintf('Peak Bump (+%.3f^\\circ at %.3fs)', maxDev_deg, peakTime));

grid on;
xlim([0, 0.2]);
ylim([0, 6.5]);

xlabel('Time (s)', 'FontSize', 11);
ylabel('Pitch Angle \theta (^\circ)', 'FontSize', 11);
title(sprintf('Phase 6C Pitch Disturbance Rejection: Peak Bump = +%.3f^\\circ, RMS Chatter = %.2f%%', ...
      maxDev_deg, rms_chatter_pct), 'FontSize', 12);

legend('Location', 'southeast', 'FontSize', 9);

%% Phase 6C — Roll Disturbance Rejection Analysis (alman Feedback)


modelName = 'Single_Axis_Roll_Disturbance_Est_Feedback';  % <-- Your model name
open_system(modelName);
sim(modelName);

data = phi;
t = data.Time;
y = data.Data(:);

% Reference and Disturbance Parameters
refValue         = deg2rad(5);   % 5 deg setpoint (0.08727 rad)
disturbanceStart = 0.100;        % 0.1s onset
disturbanceEnd   = 0.105;        % 5ms pulse duration

% Isolate post-disturbance window
idx_post = t >= disturbanceStart;
t_post   = t(idx_post);
y_post   = y(idx_post);

% Peak Deviation
deviation        = y_post - refValue;
[maxDev, maxIdx] = max(abs(deviation));
peakTime         = t_post(maxIdx);
peakAngle        = y_post(maxIdx);

% Recovery Time (2% band around 5 deg: +/-0.1 deg)
band         = 0.02 * refValue;
recovered    = false;
recoveryTime = NaN;

for k = maxIdx:length(y_post)
    if all(abs(y_post(k:end) - refValue) <= band)
        recoveryTime = t_post(k) - disturbanceStart;
        recovered    = true;
        break;
    end
end

% Display Metrics
fprintf('\n================== PHASE 6C — DISTURBANCE REJECTION (ESTIMATE FEEDBACK) ==================\n');
fprintf('Reference Target Angle         : %.5f rad (%.2f deg)\n', refValue, rad2deg(refValue));
fprintf('Peak Deviation from Target     : %.5f rad (%.3f deg)\n', maxDev, rad2deg(maxDev));
fprintf('Peak Deviation Percentage      : %.2f %% of reference\n', (maxDev / refValue) * 100);
fprintf('Time to Reach Peak Deviation   : %.4f s (after pulse onset)\n', peakTime - disturbanceStart);

if recovered
    fprintf('Recovery Time (to 2%% band)     : %.4f s (after pulse onset)\n', recoveryTime);
    fprintf('Total Settling Timestamp       : %.4f s\n', disturbanceStart + recoveryTime);
else
    fprintf('Recovery Time                  : System did NOT settle within 2%% band during simulation.\n');
end
fprintf('==========================================================================================\n');

% Zoomed Rejection Plot (Degrees)
figure('Name','Phase 6C: Roll Disturbance (Kalman Feedback)','Position',[150 150 950 520]);

y_deg         = rad2deg(y);
refValue_deg  = rad2deg(refValue);
band_deg      = rad2deg(band);
maxDev_deg    = rad2deg(maxDev);
peakAngle_deg = rad2deg(peakAngle);

t_zoom_start = 0.070;
t_zoom_end   = 0.160;
idx_zoom     = (t >= t_zoom_start) & (t <= t_zoom_end);

patch([disturbanceStart disturbanceEnd disturbanceEnd disturbanceStart], ...
      [4.5 4.5 6.0 6.0], [1 0.85 0.95], 'EdgeColor', 'none', ...
      'FaceAlpha', 0.6, 'DisplayName', 'Disturbance Pulse (5ms, 0.015 N\cdot m)');
hold on;

yline(refValue_deg + band_deg, ':r', 'LineWidth', 1.1, 'DisplayName', '\pm2% Recovery Band (\pm0.1^\circ)');
yline(refValue_deg - band_deg, ':r', 'LineWidth', 1.1, 'HandleVisibility', 'off');
yline(refValue_deg, 'k--', 'LineWidth', 1.2, 'DisplayName', 'Reference (5^\circ)');

plot(t(idx_zoom), y_deg(idx_zoom), 'b', 'LineWidth', 1.8, 'DisplayName', 'True Roll Angle \phi');
plot(peakTime, peakAngle_deg, 'ro', 'MarkerFaceColor', 'r', 'MarkerSize', 6, ...
     'DisplayName', sprintf('Peak Bump (+%.3f^\\circ)', maxDev_deg));

grid on;
xlim([t_zoom_start, t_zoom_end]);
ylim([4.8, max(5.4, peakAngle_deg + 0.1)]);

xlabel('Time (s)', 'FontSize', 11);
ylabel('Roll Angle \phi (^\circ)', 'FontSize', 11);
title(sprintf('Phase 6C Roll Disturbance Rejection: Peak Bump = +%.3f^\\circ, Recovery Time = %.4fs', ...
      maxDev_deg, recoveryTime), 'FontSize', 12);

legend('Location', 'southeast', 'FontSize', 9);

%% Phase 6C — Yaw Disturbance Rejection Analysis (alman Feedback)


modelName = 'Single_Axis_Yaw_Disturbance_Est_Feedback';  % <-- Your model name
open_system(modelName);
sim(modelName);

data = psi;
t = data.Time;
y = data.Data(:);

% Reference and Disturbance Parameters
refValue         = deg2rad(5);   % 5 deg setpoint (0.08727 rad)
disturbanceStart = 0.12;        % 0.1s onset
disturbanceEnd   = 0.1235;        % 5ms pulse duration

% Isolate post-disturbance window
idx_post = t >= disturbanceStart;
t_post   = t(idx_post);
y_post   = y(idx_post);

% Peak Deviation
deviation        = y_post - refValue;
[maxDev, maxIdx] = max(abs(deviation));
peakTime         = t_post(maxIdx);
peakAngle        = y_post(maxIdx);

% Recovery Time (2% band around 5 deg: +/-0.1 deg)
band         = 0.02 * refValue;
recovered    = false;
recoveryTime = NaN;

for k = maxIdx:length(y_post)
    if all(abs(y_post(k:end) - refValue) <= band)
        recoveryTime = t_post(k) - disturbanceStart;
        recovered    = true;
        break;
    end
end

% Display Metrics
fprintf('\n================== PHASE 6C — DISTURBANCE REJECTION (ESTIMATE FEEDBACK) ==================\n');
fprintf('Reference Target Angle         : %.5f rad (%.2f deg)\n', refValue, rad2deg(refValue));
fprintf('Peak Deviation from Target     : %.5f rad (%.3f deg)\n', maxDev, rad2deg(maxDev));
fprintf('Peak Deviation Percentage      : %.2f %% of reference\n', (maxDev / refValue) * 100);
fprintf('Time to Reach Peak Deviation   : %.4f s (after pulse onset)\n', peakTime - disturbanceStart);

if recovered
    fprintf('Recovery Time (to 2%% band)     : %.4f s (after pulse onset)\n', recoveryTime);
    fprintf('Total Settling Timestamp       : %.4f s\n', disturbanceStart + recoveryTime);
else
    fprintf('Recovery Time                  : System did NOT settle within 2%% band during simulation.\n');
end
fprintf('==========================================================================================\n');

% Zoomed Rejection Plot (Degrees)
figure('Name','Phase 6C: Roll Disturbance (Kalman Feedback)','Position',[150 150 950 520]);

y_deg         = rad2deg(y);
refValue_deg  = rad2deg(refValue);
band_deg      = rad2deg(band);
maxDev_deg    = rad2deg(maxDev);
peakAngle_deg = rad2deg(peakAngle);

t_zoom_start = 0.070;
t_zoom_end   = 0.160;
idx_zoom     = (t >= t_zoom_start) & (t <= t_zoom_end);

patch([disturbanceStart disturbanceEnd disturbanceEnd disturbanceStart], ...
      [4.5 4.5 6.0 6.0], [1 0.85 0.95], 'EdgeColor', 'none', ...
      'FaceAlpha', 0.6, 'DisplayName', 'Disturbance Pulse (5ms, 0.015 N\cdot m)');
hold on;

yline(refValue_deg + band_deg, ':r', 'LineWidth', 1.1, 'DisplayName', '\pm2% Recovery Band (\pm0.1^\circ)');
yline(refValue_deg - band_deg, ':r', 'LineWidth', 1.1, 'HandleVisibility', 'off');
yline(refValue_deg, 'k--', 'LineWidth', 1.2, 'DisplayName', 'Reference (5^\circ)');

plot(t(idx_zoom), y_deg(idx_zoom), 'b', 'LineWidth', 1.8, 'DisplayName', 'True Yaw Angle \psi');
plot(peakTime, peakAngle_deg, 'ro', 'MarkerFaceColor', 'r', 'MarkerSize', 6, ...
     'DisplayName', sprintf('Peak Bump (+%.3f^\\circ)', maxDev_deg));

grid on;
xlim([t_zoom_start, t_zoom_end]);
ylim([4.8, max(5.4, peakAngle_deg + 0.1)]);

xlabel('Time (s)', 'FontSize', 11);
ylabel('Roll Angle \phi (^\circ)', 'FontSize', 11);
title(sprintf('Phase 6C Yaw Disturbance Rejection: Peak Bump = +%.3f^\\circ, Recovery Time = %.4fs', ...
      maxDev_deg, recoveryTime), 'FontSize', 12);

legend('Location', 'southeast', 'FontSize', 9);


%% Phase 6D — Pitch Disturbance Severity Sweep (Estimate Feedback)


modelName = 'Single_Axis_Pitch_Disturbance_Est_Feedback';   % <-- your Kalman-feedback pitch model
open_system(modelName);

% Block paths to your two disturbance Step blocks — replace with actual paths
% (click each block, type `gcb` in Command Window to get exact path string)
stepUpBlock   = [modelName '/Pitch Axis Dynamics/Step_ON'];
stepDownBlock = [modelName '/Pitch Axis Dynamics/Step_OFF'];

baseAmplitude = 0.0003;           % pitch's original 1x disturbance (N*m)
severityMultipliers = [1, 2, 4, 8];

refValue = deg2rad(5);
disturbanceStart = 0.100;         % corrected onset, past pitch's step response
disturbanceEnd   = 0.1035;
tailMargin = 0.03;                % how far past disturbanceEnd counts as "settled" window

results = table('Size', [length(severityMultipliers) 5], ...
    'VariableTypes', {'double','double','double','double','string'}, ...
    'VariableNames', {'Multiplier','Amplitude_Nm','PeakDeviation_pct', ...
                       'RMS_Chatter_pct','Status'});

figure('Name','Phase 6D — Pitch Severity Sweep','Position',[100 100 1100 750]);

for i = 1:length(severityMultipliers)
    mult = severityMultipliers(i);
    amp = baseAmplitude * mult;
    
    % Push the scaled amplitude into both step blocks (down-step is negative)
    set_param(stepUpBlock, 'After', num2str(amp));
    set_param(stepDownBlock, 'After', num2str(-amp));
    
    simOut = sim(modelName);
    
    % Pull true theta — adjust variable/signal name to match your model
    data = theta;   % or evalin('base','theta') if using To Workspace
    t = data.Time;
    y = data.Data(:);
    
    idx_post = t >= disturbanceStart;
    t_post = t(idx_post);
    y_post = y(idx_post);
    
    deviation = y_post - refValue;
    [maxDev, ~] = max(abs(deviation));
    
    tail_window = t >= (disturbanceEnd + tailMargin);
    y_tail = y(tail_window);
    rms_chatter = sqrt(mean((y_tail - refValue).^2));
    
    peakPct = 100 * maxDev / refValue;
    chatterPct = 100 * rms_chatter / refValue;
    
    if max(abs(y)) > 3*refValue || any(isnan(y))
        status = "DIVERGED";
    elseif chatterPct > 5
        status = "UNSTABLE CHATTER";
    elseif chatterPct > 2
        status = "PERSISTENT CHATTER";
    else
        status = "SETTLES CLEANLY";
    end
    
    results.Multiplier(i) = mult;
    results.Amplitude_Nm(i) = amp;
    results.PeakDeviation_pct(i) = peakPct;
    results.RMS_Chatter_pct(i) = chatterPct;
    results.Status(i) = status;
    
    subplot(2,2,i);
    plot(t, rad2deg(y), 'b', 'LineWidth', 1.3); hold on;
    yline(rad2deg(refValue), '--k', 'Reference');
    grid on;
    xlim([0.05 0.2]);
    title(sprintf('%dx baseline (%.4g N*m): peak=%.2f%%, chatter=%.2f%%', ...
        mult, amp, peakPct, chatterPct));
    xlabel('Time (s)'); ylabel('\theta (deg)');
end

fprintf('\n================== PHASE 6D — PITCH SEVERITY SWEEP ==================\n');
disp(results)

%% Phase 6D — Roll Disturbance Severity Sweep (Estimate Feedback)


modelName = 'Single_Axis_Roll_Disturbance_Est_Feedback';   % <-- your roll estimate-feedback model
open_system(modelName);

stepUpBlock   = [modelName '/Roll Axis Dynamics/Step_ON'];    % confirm via gcb on each block
stepDownBlock = [modelName '/Roll Axis Dynamics/Step_OFF'];

baseAmplitude = 0.015;             % roll's original 1x disturbance (N*m)
severityMultipliers = [1, 2, 4, 8];

refValue = deg2rad(5);
disturbanceStart = 0.100;          % roll's onset
disturbanceEnd   = 0.105;          % roll's 5ms pulse width
tailMargin = 0.03;

results = table('Size', [length(severityMultipliers) 5], ...
    'VariableTypes', {'double','double','double','double','string'}, ...
    'VariableNames', {'Multiplier','Amplitude_Nm','PeakDeviation_pct', ...
                       'RMS_Chatter_pct','Status'});

figure('Name','Phase 6D — Roll Severity Sweep','Position',[100 100 1100 750]);

for i = 1:length(severityMultipliers)
    mult = severityMultipliers(i);
    amp = baseAmplitude * mult;
    
    set_param(stepUpBlock, 'After', num2str(amp));
    set_param(stepDownBlock, 'After', num2str(-amp));
    
    simOut = sim(modelName);
    
    data = phi;   % adjust to match your actual signal/variable name
    t = data.Time;
    y = data.Data(:);
    
    idx_post = t >= disturbanceStart;
    t_post = t(idx_post);
    y_post = y(idx_post);
    
    deviation = y_post - refValue;
    [maxDev, ~] = max(abs(deviation));
    
    tail_window = t >= (disturbanceEnd + tailMargin);
    y_tail = y(tail_window);
    rms_chatter = sqrt(mean((y_tail - refValue).^2));
    
    peakPct = 100 * maxDev / refValue;
    chatterPct = 100 * rms_chatter / refValue;
    
    if max(abs(y)) > 3*refValue || any(isnan(y))
        status = "DIVERGED";
    elseif chatterPct > 5
        status = "UNSTABLE CHATTER";
    elseif chatterPct > 2
        status = "PERSISTENT CHATTER";
    else
        status = "SETTLES CLEANLY";
    end
    
    results.Multiplier(i) = mult;
    results.Amplitude_Nm(i) = amp;
    results.PeakDeviation_pct(i) = peakPct;
    results.RMS_Chatter_pct(i) = chatterPct;
    results.Status(i) = status;
    
    subplot(2,2,i);
    plot(t, rad2deg(y), 'b', 'LineWidth', 1.3); hold on;
    yline(rad2deg(refValue), '--k', 'Reference');
    grid on;
    xlim([0.05 0.3]);
    title(sprintf('%dx baseline (%.4g N*m): peak=%.2f%%, chatter=%.2f%%', ...
        mult, amp, peakPct, chatterPct));
    xlabel('Time (s)'); ylabel('\phi (deg)');
end

fprintf('\n================== PHASE 6D — ROLL SEVERITY SWEEP ==================\n');
disp(results)

%% Phase 6D — Yaw Disturbance Severity Sweep (Estimate Feedback)


modelName = 'Single_Axis_Yaw_Disturbance_Est_Feedback';   % <-- your yaw estimate-feedback model
open_system(modelName);

stepUpBlock   = [modelName '/Yaw Axis Dynamics/Step_ON'];    % confirm via gcb on each block
stepDownBlock = [modelName '/Yaw Axis Dynamics/Step_OFF'];

baseAmplitude = 0.001;             % yaw's original 1x disturbance (N*m)
severityMultipliers = [1, 2, 4, 8];

refValue = deg2rad(5);
disturbanceStart = 0.120;          % yaw's revised, safer onset
disturbanceEnd   = 0.1235;         % yaw's pulse width
tailMargin = 0.03;

results = table('Size', [length(severityMultipliers) 5], ...
    'VariableTypes', {'double','double','double','double','string'}, ...
    'VariableNames', {'Multiplier','Amplitude_Nm','PeakDeviation_pct', ...
                       'RMS_Chatter_pct','Status'});

figure('Name','Phase 6D — Yaw Severity Sweep','Position',[100 100 1100 750]);

for i = 1:length(severityMultipliers)
    mult = severityMultipliers(i);
    amp = baseAmplitude * mult;
    
    set_param(stepUpBlock, 'After', num2str(amp));
    set_param(stepDownBlock, 'After', num2str(-amp));
    
    simOut = sim(modelName);
    
    data = psi;   % adjust to match your actual signal/variable name
    t = data.Time;
    y = data.Data(:);
    
    idx_post = t >= disturbanceStart;
    t_post = t(idx_post);
    y_post = y(idx_post);
    
    deviation = y_post - refValue;
    [maxDev, ~] = max(abs(deviation));
    
    tail_window = t >= (disturbanceEnd + tailMargin);
    y_tail = y(tail_window);
    rms_chatter = sqrt(mean((y_tail - refValue).^2));
    
    peakPct = 100 * maxDev / refValue;
    chatterPct = 100 * rms_chatter / refValue;
    
    if max(abs(y)) > 3*refValue || any(isnan(y))
        status = "DIVERGED";
    elseif chatterPct > 5
        status = "UNSTABLE CHATTER";
    elseif chatterPct > 2
        status = "PERSISTENT CHATTER";
    else
        status = "SETTLES CLEANLY";
    end
    
    results.Multiplier(i) = mult;
    results.Amplitude_Nm(i) = amp;
    results.PeakDeviation_pct(i) = peakPct;
    results.RMS_Chatter_pct(i) = chatterPct;
    results.Status(i) = status;
    
    subplot(2,2,i);
    plot(t, rad2deg(y), 'b', 'LineWidth', 1.3); hold on;
    yline(rad2deg(refValue), '--k', 'Reference');
    grid on;
    xlim([0.08 0.3]);
    title(sprintf('%dx baseline (%.4g N*m): peak=%.2f%%, chatter=%.2f%%', ...
        mult, amp, peakPct, chatterPct));
    xlabel('Time (s)'); ylabel('\psi (deg)');
end

fprintf('\n================== PHASE 6D — YAW SEVERITY SWEEP ==================\n');
disp(results)

%% Phase 6E — Simultaneous Multi-Axis Disturbance (Coupled Model, Estimate Feedback)


modelName = 'Simultaneous_Multi_Axis_Disturbance_model';   % <-- your Phase 4/5D coupled model filename
open_system(modelName);

%% Reference amplitude for this run — change to deg2rad(57.3) for the aggressive test
refAmplitude = deg2rad(57.3);

set_param([modelName '/r_phi'],   'After', num2str(refAmplitude));
set_param([modelName '/r_theta'], 'After', num2str(refAmplitude));
set_param([modelName '/r_psi'],   'After', num2str(refAmplitude));

%% Disturbance parameters — shared onset, per-axis proportional duration
distStart = 0.150;

rollAmp  = 0.015;    rollDistEnd  = 0.155;     % 5ms pulse
pitchAmp = 0.0003;   pitchDistEnd = 0.1535;    % 3.5ms pulse
yawAmp   = 0.001;    yawDistEnd   = 0.1577;    % 7.7ms pulse

% Confirm each block path via gcb before running — these are placeholders
set_param([modelName '/Roll Axis Dynamics/Step_ON'],  'Time', num2str(distStart),   'After', num2str(rollAmp));
set_param([modelName '/Roll Axis Dynamics/Step_OFF'], 'Time', num2str(rollDistEnd), 'After', num2str(-rollAmp));

set_param([modelName '/Pitch Axis Dynamics/Step_ON'],  'Time', num2str(distStart),    'After', num2str(pitchAmp));
set_param([modelName '/Pitch Axis Dynamics/Step_OFF'], 'Time', num2str(pitchDistEnd), 'After', num2str(-pitchAmp));

set_param([modelName '/Yaw Axis Dynamics/Step_ON'],  'Time', num2str(distStart),  'After', num2str(yawAmp));
set_param([modelName '/Yaw Axis Dynamics/Step_OFF'], 'Time', num2str(yawDistEnd), 'After', num2str(-yawAmp));

%% Run simulation
simOut = sim(modelName);

%% Analyze all three axes
trueVarNames = {'phi', 'theta', 'psi'};
labels = {'phi', 'theta', 'psi'};

lastPulseEnd = max([rollDistEnd, pitchDistEnd, yawDistEnd]);   % latest pulse end, for tail window

results = table('Size', [3 4], ...
    'VariableTypes', {'string','double','double','string'}, ...
    'VariableNames', {'Axis','PeakDeviation_pct','RMS_Chatter_pct','Status'});

figure('Name','Phase 6E — Simultaneous Multi-Axis Disturbance','Position',[100 100 1300 420]);

for i = 1:3
    data = evalin('base', trueVarNames{i});   % adjust if using To Workspace struct instead
    t = data.Time;
    y = data.Data(:);
    
    idx_post = t >= distStart;
    deviation = y(idx_post) - refAmplitude;
    [maxDev, ~] = max(abs(deviation));
    
    tail_window = t >= (lastPulseEnd + 0.03);
    y_tail = y(tail_window);
    rms_chatter = sqrt(mean((y_tail - refAmplitude).^2));
    
    peakPct = 100 * maxDev / refAmplitude;
    chatterPct = 100 * rms_chatter / refAmplitude;
    
    if max(abs(y)) > 3*refAmplitude || any(isnan(y))
        status = "DIVERGED";
    elseif chatterPct > 5
        status = "UNSTABLE CHATTER";
    elseif chatterPct > 2
        status = "PERSISTENT CHATTER";
    else
        status = "SETTLES CLEANLY";
    end
    
    results.Axis(i) = labels{i};
    results.PeakDeviation_pct(i) = peakPct;
    results.RMS_Chatter_pct(i) = chatterPct;
    results.Status(i) = status;
    
    subplot(1,3,i);
    plot(t, rad2deg(y), 'b', 'LineWidth', 1.3); hold on;
    yline(rad2deg(refAmplitude), '--k', 'Reference');
    xline(distStart, ':r', 'Disturbance');
    grid on;
    title(sprintf('%s: peak=%.2f%%, chatter=%.2f%%', labels{i}, peakPct, chatterPct));
    xlabel('Time (s)'); ylabel('deg');
end

fprintf('\n================== PHASE 6E — SIMULTANEOUS DISTURBANCE (ref=%.1f deg) ==================\n', rad2deg(refAmplitude));
disp(results)

%% Phase 7 — Attitude Magnitude Sweep, Coupled + Disturbance (Estimate Feedback)


modelName = 'Simultaneous_Multi_Axis_Disturbance_model';   % <-- your coupled estimate-feedback model
open_system(modelName);

angleSweep_deg = [5, 10, 20, 30, 40, 50, 57.3];

labels = {'phi', 'theta', 'psi'};
trueVarNames = {'phi', 'theta', 'psi'};   % adjust to match your To Workspace names

%% Disturbance parameters — identical to Phase 6E
distStart = 0.150;

rollAmp  = 0.015;    rollDistEnd  = 0.155;     % 5ms pulse
pitchAmp = 0.0003;   pitchDistEnd = 0.1535;    % 3.5ms pulse
yawAmp   = 0.001;    yawDistEnd   = 0.1577;    % 7.7ms pulse

lastPulseEnd = max([rollDistEnd, pitchDistEnd, yawDistEnd]);

% Set disturbance blocks once — same for every angle in the sweep
set_param([modelName '/Roll Axis Dynamics/Step_ON'],  'Time', num2str(distStart),   'After', num2str(rollAmp));
set_param([modelName '/Roll Axis Dynamics/Step_OFF'], 'Time', num2str(rollDistEnd), 'After', num2str(-rollAmp));

set_param([modelName '/Pitch Axis Dynamics/Step_ON'],  'Time', num2str(distStart),    'After', num2str(pitchAmp));
set_param([modelName '/Pitch Axis Dynamics/Step_OFF'], 'Time', num2str(pitchDistEnd), 'After', num2str(-pitchAmp));

set_param([modelName '/Yaw Axis Dynamics/Step_ON'],  'Time', num2str(distStart),  'After', num2str(yawAmp));
set_param([modelName '/Yaw Axis Dynamics/Step_OFF'], 'Time', num2str(yawDistEnd), 'After', num2str(-yawAmp));

%% Results table
results = table('Size', [length(angleSweep_deg)*3 6], ...
    'VariableTypes', {'double','string','double','double','double','string'}, ...
    'VariableNames', {'Angle_deg','Axis','Overshoot_pct','SettlingTime_s','RMS_Chatter_pct','Status'});

rowIdx = 1;

for a = 1:length(angleSweep_deg)
    refAmplitude = deg2rad(angleSweep_deg(a));
    
    set_param([modelName '/r_phi'],   'After', num2str(refAmplitude));
    set_param([modelName '/r_theta'], 'After', num2str(refAmplitude));
    set_param([modelName '/r_psi'],   'After', num2str(refAmplitude));
    
    simOut = sim(modelName);
    
    for i = 1:3
        data = evalin('base', trueVarNames{i});
        t = data.Time;
        y = data.Data(:);
        
        try
            info = stepinfo(y, t, refAmplitude);
            overshoot = info.Overshoot;
            settlingTime = info.SettlingTime;
        catch
            overshoot = NaN;
            settlingTime = NaN;
        end
        
        % Post-disturbance chatter, same method as 6D/6E
        tail_window = t >= (lastPulseEnd + 0.03);
        y_tail = y(tail_window);
        rms_chatter = sqrt(mean((y_tail - refAmplitude).^2));
        chatterPct = 100 * rms_chatter / refAmplitude;
        
        if isnan(settlingTime) || max(abs(y)) > 3*refAmplitude
            status = "UNACCEPTABLE (unbounded/never settles)";
        elseif overshoot > 20 || chatterPct > 5
            status = "UNACCEPTABLE (overshoot/chatter)";
        elseif overshoot > 5 || chatterPct > 2
            status = "DEGRADING";
        else
            status = "ACCEPTABLE";
        end
        
        results.Angle_deg(rowIdx) = angleSweep_deg(a);
        results.Axis(rowIdx) = labels{i};
        results.Overshoot_pct(rowIdx) = overshoot;
        results.SettlingTime_s(rowIdx) = settlingTime;
        results.RMS_Chatter_pct(rowIdx) = chatterPct;
        results.Status(rowIdx) = status;
        rowIdx = rowIdx + 1;
    end
end

fprintf('\n================== PHASE 7 — ANGLE SWEEP + DISTURBANCE (COUPLED, ESTIMATE FEEDBACK) ==================\n');
disp(results)

%% Phase 7 (isolation test) — Coupled, NO Disturbance, Attitude Sweep

modelName = 'Simultaneous_Multi_Axis_Disturbance_model';   % <-- your coupled estimate-feedback model
open_system(modelName);

angleSweep_deg = [5, 10, 57.3];

labels = {'phi', 'theta', 'psi'};
trueVarNames = {'phi', 'theta', 'psi'};   % adjust to match your To Workspace names

%% Zero out the disturbance blocks — same blocks as 6E, amplitude set to 0
distStart = 0.150;
rollDistEnd  = 0.155;
pitchDistEnd = 0.1535;
yawDistEnd   = 0.1577;
lastPulseEnd = max([rollDistEnd, pitchDistEnd, yawDistEnd]);

set_param([modelName '/Roll Axis Dynamics/Step_ON'],  'Time', num2str(distStart),   'After', '0');
set_param([modelName '/Roll Axis Dynamics/Step_OFF'], 'Time', num2str(rollDistEnd), 'After', '0');

set_param([modelName '/Pitch Axis Dynamics/Step_ON'],  'Time', num2str(distStart),    'After', '0');
set_param([modelName '/Pitch Axis Dynamics/Step_OFF'], 'Time', num2str(pitchDistEnd), 'After', '0');

set_param([modelName '/Yaw Axis Dynamics/Step_ON'],  'Time', num2str(distStart),  'After', '0');
set_param([modelName '/Yaw Axis Dynamics/Step_OFF'], 'Time', num2str(yawDistEnd), 'After', '0');

%% Results table
results = table('Size', [length(angleSweep_deg)*3 6], ...
    'VariableTypes', {'double','string','double','double','double','string'}, ...
    'VariableNames', {'Angle_deg','Axis','Overshoot_pct','SettlingTime_s','RMS_Chatter_pct','Status'});

rowIdx = 1;

for a = 1:length(angleSweep_deg)
    refAmplitude = deg2rad(angleSweep_deg(a));
    
    set_param([modelName '/r_phi'],   'After', num2str(refAmplitude));
    set_param([modelName '/r_theta'], 'After', num2str(refAmplitude));
    set_param([modelName '/r_psi'],   'After', num2str(refAmplitude));
    
    simOut = sim(modelName);
    
    for i = 1:3
        data = evalin('base', trueVarNames{i});
        t = data.Time;
        y = data.Data(:);
        
        try
            info = stepinfo(y, t, refAmplitude);
            overshoot = info.Overshoot;
            settlingTime = info.SettlingTime;
        catch
            overshoot = NaN;
            settlingTime = NaN;
        end
        
        tail_window = t >= (lastPulseEnd + 0.03);
        y_tail = y(tail_window);
        rms_chatter = sqrt(mean((y_tail - refAmplitude).^2));
        chatterPct = 100 * rms_chatter / refAmplitude;
        
        if isnan(settlingTime) || max(abs(y)) > 3*refAmplitude
            status = "UNACCEPTABLE (unbounded/never settles)";
        elseif overshoot > 20 || chatterPct > 5
            status = "UNACCEPTABLE (overshoot/chatter)";
        elseif overshoot > 5 || chatterPct > 2
            status = "DEGRADING";
        else
            status = "ACCEPTABLE";
        end
        
        results.Angle_deg(rowIdx) = angleSweep_deg(a);
        results.Axis(rowIdx) = labels{i};
        results.Overshoot_pct(rowIdx) = overshoot;
        results.SettlingTime_s(rowIdx) = settlingTime;
        results.RMS_Chatter_pct(rowIdx) = chatterPct;
        results.Status(rowIdx) = status;
        rowIdx = rowIdx + 1;
    end
end

fprintf('\n================== PHASE 7 (ISOLATION) — COUPLED, NO DISTURBANCE ==================\n');
disp(results)

%% Phase 8 — Combined Stress Test: Angle x Disturbance Severity (Coupled, Estimate Feedback)

modelName = 'Simultaneous_Multi_Axis_Disturbance_model';   % <-- your coupled estimate-feedback model
open_system(modelName);

angleSweep_deg = [5, 10, 20, 30, 57.3, 90, 120, 180];
severityMultipliers = [1, 2, 4, 8, 16, 32, 64];

labels = {'phi', 'theta', 'psi'};
trueVarNames = {'phi', 'theta', 'psi'};

% Base disturbance parameters (1x, from Phase 6A)
rollAmpBase  = 0.015;
pitchAmpBase = 0.0003;
yawAmpBase   = 0.001;

distStart = 0.150;
rollDistEnd  = 0.155;
pitchDistEnd = 0.1535;
yawDistEnd   = 0.1577;
lastPulseEnd = max([rollDistEnd, pitchDistEnd, yawDistEnd]);

nAngles = length(angleSweep_deg);
nSev = length(severityMultipliers);
nRows = nAngles * nSev * 3;

results = table('Size', [nRows 7], ...
    'VariableTypes', {'double','double','string','double','double','double','string'}, ...
    'VariableNames', {'Angle_deg','Severity_x','Axis','Overshoot_pct','SettlingTime_s', ...
                       'RMS_Chatter_pct','Status'});

rowIdx = 1;

for s = 1:nSev
    mult = severityMultipliers(s);
    
    % Scale disturbance amplitude for this severity level
    set_param([modelName '/Roll Axis Dynamics/Step_ON'],  'Time', num2str(distStart),   'After', num2str(rollAmpBase*mult));
    set_param([modelName '/Roll Axis Dynamics/Step_OFF'], 'Time', num2str(rollDistEnd), 'After', num2str(-rollAmpBase*mult));
    
    set_param([modelName '/Pitch Axis Dynamics/Step_ON'],  'Time', num2str(distStart),    'After', num2str(pitchAmpBase*mult));
    set_param([modelName '/Pitch Axis Dynamics/Step_OFF'], 'Time', num2str(pitchDistEnd), 'After', num2str(-pitchAmpBase*mult));
    
    set_param([modelName '/Yaw Axis Dynamics/Step_ON'],  'Time', num2str(distStart),  'After', num2str(yawAmpBase*mult));
    set_param([modelName '/Yaw Axis Dynamics/Step_OFF'], 'Time', num2str(yawDistEnd), 'After', num2str(-yawAmpBase*mult));
    
    for a = 1:nAngles
        refAmplitude = deg2rad(angleSweep_deg(a));
        
        set_param([modelName '/r_phi'],   'After', num2str(refAmplitude));
        set_param([modelName '/r_theta'], 'After', num2str(refAmplitude));
        set_param([modelName '/r_psi'],   'After', num2str(refAmplitude));
        
        try
            simOut = sim(modelName);
        catch
            % Simulation itself failed (e.g. numerical blow-up) — record as diverged
            for i = 1:3
                results.Angle_deg(rowIdx) = angleSweep_deg(a);
                results.Severity_x(rowIdx) = mult;
                results.Axis(rowIdx) = labels{i};
                results.Overshoot_pct(rowIdx) = NaN;
                results.SettlingTime_s(rowIdx) = NaN;
                results.RMS_Chatter_pct(rowIdx) = NaN;
                results.Status(rowIdx) = "DIVERGED (sim failed)";
                rowIdx = rowIdx + 1;
            end
            continue
        end
        
        for i = 1:3
            data = evalin('base', trueVarNames{i});
            t = data.Time;
            y = data.Data(:);
            
            try
                info = stepinfo(y, t, refAmplitude);
                overshoot = info.Overshoot;
                settlingTime = info.SettlingTime;
            catch
                overshoot = NaN;
                settlingTime = NaN;
            end
            
            tail_window = t >= (lastPulseEnd + 0.03);
            y_tail = y(tail_window);
            rms_chatter = sqrt(mean((y_tail - refAmplitude).^2));
            chatterPct = 100 * rms_chatter / refAmplitude;
            
            if any(isnan(y)) || max(abs(y)) > 3*refAmplitude
                status = "DIVERGED";
            elseif isnan(settlingTime)
                if chatterPct > 5
                    status = "UNACCEPTABLE (unstable chatter)";
                else
                    status = "DEGRADING (never settles, bounded)";
                end
            elseif overshoot > 20 || chatterPct > 5
                status = "UNACCEPTABLE";
            elseif overshoot > 5 || chatterPct > 2
                status = "DEGRADING";
            else
                status = "ACCEPTABLE";
            end
            
            results.Angle_deg(rowIdx) = angleSweep_deg(a);
            results.Severity_x(rowIdx) = mult;
            results.Axis(rowIdx) = labels{i};
            results.Overshoot_pct(rowIdx) = overshoot;
            results.SettlingTime_s(rowIdx) = settlingTime;
            results.RMS_Chatter_pct(rowIdx) = chatterPct;
            results.Status(rowIdx) = status;
            rowIdx = rowIdx + 1;
        end
    end
end

fprintf('\n================== PHASE 8 — COMBINED ANGLE x SEVERITY STRESS TEST ==================\n');
disp(results)

% Quick filter: show only rows where anything actually diverged
divergedRows = results(contains(results.Status, "DIVERGED"), :);
fprintf('\n--- Rows where DIVERGENCE occurred ---\n');
disp(divergedRows)

% Quick filter: pitch-only view for easy reading
pitchRows = results(results.Axis == "theta", :);
fprintf('\n--- Pitch (theta) results only ---\n');
disp(pitchRows)



