#!/usr/bin/env bash 

cd /var/www/html
mv admin admin2

mysql -h mysql -uroot -p$DB_PASSWD prestashop -e "update ps_configuration set value=NULL where name like 'PS_TAX%';;commit;" 
mysql -h mysql -uroot -p$DB_PASSWD prestashop -e "update ps_configuration set value='0' where name='PS_SHIPPING_HANDLING';commit;" 
mysql -h mysql -uroot -p$DB_PASSWD prestashop -e "delete from  ps_specific_price;commit;" 
mysql -h mysql -uroot -p$DB_PASSWD prestashop -e "update ps_product set quantity=id_product;commit;"
