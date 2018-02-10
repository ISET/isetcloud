num_samples = 2200;
batch_size = 12;
epoch = num_samples/batch_size;
loss = '/Users/eugeneliu/Desktop/training20180207/run_train-tag-TotalLoss.csv';
person = '/Users/eugeneliu/Desktop/training20180207/run_.-tag-PASCAL_PerformanceByCategory_AP@0.5IOU_person.csv';
car = '/Users/eugeneliu/Desktop/training20180207/run_.-tag-PASCAL_PerformanceByCategory_AP@0.5IOU_car.csv';
bus = '/Users/eugeneliu/Desktop/training20180207/run_.-tag-PASCAL_PerformanceByCategory_AP@0.5IOU_bus.csv';
mAP = '/Users/eugeneliu/Desktop/training20180207/run_.-tag-PASCAL_Precision_mAP@0.5IOU.csv';
Array_loss = csvread(loss,2);
steps_loss = Array_loss(:, 2);
num_epoch_loss = steps_loss/epoch;
loss_val = Array_loss(:, 3);
log_epoch_loss = log(num_epoch_loss);
plot(num_epoch_loss,log_epoch_loss,loss_val,'LineWidth',2.5,'color',[253/256,112/256,74/256]);
plot(log_epoch_loss,loss_val,'LineWidth',2.5,'color',[253/256,112/256,74/256]);
grid on
grid minor
legend('loss')
set(gca, 'YMinorTick','on')
set(gca, 'XMinorTick','on')
set(gca,'FontSize',12);
title('Train:Total loss vs Epochs')
xlabel('Number of Training epochs')
ylabel('Total loss')

figure;
Array_person=csvread(person,2);
steps = Array_person(:, 2); % Steps are the same across all category 
num_epoch = steps/epoch; % num_epochs are the same across all category 
AP_person = Array_person(:, 3);
log_epoch = log(num_epoch);
plot(num_epoch, AP_person,'LineWidth',1.5,'color',[58/256,120/256,68/256]);
figure;
plot(log_epoch, AP_person,'LineWidth',1.5,'color',[58/256,120/256,68/256]);

figure;
plot3(num_epoch,log_epoch, AP_person,'LineWidth',1.5,'color',[58/256,120/256,68/256]);
hold on

Array_car =csvread(car,2);
AP_car = Array_car(:, 3);
log_epoch = log(num_epoch);
plot3(num_epoch,log_epoch, AP_car,'LineWidth',1.5,'color',[191/256,121/256,66/256]);
hold on

Array_bus =csvread(bus,2);
AP_bus = Array_bus(:, 3);
log_epoch = log(num_epoch);
plot3(num_epoch,log_epoch, AP_bus,'LineWidth',1.5,'color',[66/256,99/256,206/256]);
hold on

Array_mAP =csvread(mAP,2);
mAP = Array_mAP(:, 3);
log_epoch = log(num_epoch);
plot3(num_epoch,log_epoch, mAP,'LineWidth',3.5,'color',[245/256,62/256,12/256])

legend('Person','Car','Bus','mAP')

grid on
grid minor

set(gca, 'YMinorTick','on')
set(gca, 'XMinorTick','on')
set(gca,'FontSize',12);
title('PASCAL Performance By Category vs Epochs')
xlabel('Number of Training epochs')
ylabel('Mean Average Precision')
ylim([0 1]);



