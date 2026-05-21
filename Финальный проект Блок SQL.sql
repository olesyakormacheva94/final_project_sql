-- 1. Список клиентов с непрерывной историей за год, то есть каждый месяц на регулярной основе без пропусков за указанный годовой период: 
-- средний чек за период с 01.06.2015 по 01.06.2016, 
-- средняя сумма покупок за месяц, 
-- количество всех операций по клиенту за период

SELECT 
    ID_client,
    AVG(Sum_payment) AS avg_check, -- средний чек клиента за весь период
    SUM(Sum_payment) / 12 AS avg_monthly_purchase, -- средняя сумма покупок за месяц (т.к. в выборку попадут только клиенты без пропусков, можем поделить на 12)
    COUNT(DISTINCT Id_check) AS total_transactions -- кол-во всех операций (уникальных чеков) по клиенту за период
FROM 
    transactions
WHERE 
    date_new >= '2015-06-01' AND date_new < '2016-06-01'
GROUP BY 
    ID_client
HAVING 
    COUNT(DISTINCT DATE_FORMAT(date_new, '%Y-%m')) = 12; -- форматируем дату в год-месяц и считаем количество уникальных месяцев и выбираем только тех клиентов, у которых ровно 12 - то есть покупал непрерывно

-- 2. Информация в разрезе месяцев:
-- средняя сумма чека в месяц;
-- среднее количество операций в месяц;
-- среднее количество клиентов, которые совершали операции;
-- долю от общего количества операций за год и долю в месяц от общей суммы операций;
-- вывести % соотношение M/F/NA в каждом месяце с их долей затрат;

WITH 
year_totals AS (
    SELECT 
        COUNT(DISTINCT Id_check) AS total_year_transactions,
        SUM(Sum_payment) AS total_year_revenue
    FROM transactions
    WHERE date_new >= '2015-06-01' AND date_new < '2016-06-01'
),

monthly_metrics AS (
    SELECT 
        DATE_FORMAT(t.date_new, '%Y-%m') AS month_period,
        SUM(t.Sum_payment) / COUNT(DISTINCT t.Id_check) AS avg_check_monthly, -- средняя сумма чека в месяц
        -- вспомогательные метрики для долей и средних значений:
        COUNT(DISTINCT t.Id_check) AS monthly_transactions_count,
        SUM(t.Sum_payment) AS monthly_revenue_sum,
        COUNT(DISTINCT t.ID_client) AS monthly_active_clients
    FROM transactions t
    WHERE t.date_new >= '2015-06-01' AND t.date_new < '2016-06-01'
    GROUP BY DATE_FORMAT(t.date_new, '%Y-%m')
),

-- доли по полу (M/F/NA) и их затраты для каждого месяца:
gender_metrics AS (
    SELECT 
        DATE_FORMAT(t.date_new, '%Y-%m') AS month_period,
        
        -- количество клиентов каждого пола в месяце:
        COUNT(DISTINCT CASE WHEN c.Gender = 'M' THEN t.ID_client END) AS count_M,
        COUNT(DISTINCT CASE WHEN c.Gender = 'F' THEN t.ID_client END) AS count_F,
        COUNT(DISTINCT CASE WHEN c.Gender IS NULL OR c.Gender = 'NA' OR c.Gender = '' THEN t.ID_client END) AS count_NA,
        
        -- сумма затрат каждого пола в месяце:
        SUM(CASE WHEN c.Gender = 'M' THEN t.Sum_payment ELSE 0 END) AS revenue_M,
        SUM(CASE WHEN c.Gender = 'F' THEN t.Sum_payment ELSE 0 END) AS revenue_F,
        SUM(CASE WHEN c.Gender IS NULL OR c.Gender = 'NA' OR c.Gender = '' THEN t.Sum_payment ELSE 0 END) AS revenue_NA
    FROM transactions t
    LEFT JOIN customers c ON t.ID_client = c.Id_client
    WHERE t.date_new >= '2015-06-01' AND t.date_new < '2016-06-01'
    GROUP BY DATE_FORMAT(t.date_new, '%Y-%m')
)
-- финальная таблица:
SELECT 
    m.month_period AS `Месяц`,
    ROUND(m.avg_check_monthly, 2) AS `Средний чек`,
    m.monthly_transactions_count AS `Кол-во операций`,
    m.monthly_active_clients AS `Кол-во активных клиентов`,
    
    -- доля операций за месяц от общего количества операций за год:
    ROUND((m.monthly_transactions_count / y.total_year_transactions) * 100, 2) AS `Доля операций от года, %`,
    -- доля суммы за месяц от общей суммы операций за год:
    ROUND((m.monthly_revenue_sum / y.total_year_revenue) * 100, 2) AS `Доля выручки от года, %`,
    
    -- процентное соотношение по полу (M/F/NA) среди клиентов в этом месяце:
    ROUND((g.count_M / m.monthly_active_clients) * 100, 2) AS `Клиенты M, %`,
    ROUND((g.count_F / m.monthly_active_clients) * 100, 2) AS `Клиенты F, %`,
    ROUND((g.count_NA / m.monthly_active_clients) * 100, 2) AS `Клиенты NA, %`,
    
    -- доля затрат (выручки) по полу в рамках этого месяца:
    ROUND((g.revenue_M / m.monthly_revenue_sum) * 100, 2) AS `Доля затрат M, %`,
    ROUND((g.revenue_F / m.monthly_revenue_sum) * 100, 2) AS `Доля затрат F, %`,
    ROUND((g.revenue_NA / m.monthly_revenue_sum) * 100, 2) AS `Доля затрат NA, %`

FROM monthly_metrics m
JOIN gender_metrics g ON m.month_period = g.month_period
CROSS JOIN year_totals y
ORDER BY m.month_period;

-- 3. Возрастные группы клиентов с шагом 10 лет и отдельно клиентов, у которых нет данной информации, с параметрами:
--  сумма и количество операций за весь период,
--  поквартально - средние показатели и %

 -- 3.1. Общие итоги по возрастным группам за весь период:
 
 SELECT 
    CASE 
        WHEN c.Age IS NULL THEN 'Нет данных'
        ELSE CONCAT(FLOOR(c.Age / 10) * 10, '-', (FLOOR(c.Age / 10) * 10) + 9)
    END AS age_group,
    SUM(t.Sum_payment) AS total_revenue,
    COUNT(DISTINCT t.Id_check) AS total_transactions
FROM 
    transactions t
LEFT JOIN 
    customers c ON t.ID_client = c.Id_client
WHERE 
    t.date_new >= '2015-06-01' AND t.date_new < '2016-06-01'
GROUP BY 
    age_group
ORDER BY 
    MIN(c.Age);

-- 3.2. Поквартально:

WITH quarterly_raw AS (
    -- сырые показатели по кварталам и возрастным группам
    SELECT 
        CONCAT(YEAR(t.date_new), '-Q', QUARTER(t.date_new)) AS quarter_period,
        CASE 
            WHEN c.Age IS NULL THEN 'Нет данных'
            ELSE CONCAT(FLOOR(c.Age / 10) * 10, '-', (FLOOR(c.Age / 10) * 10) + 9)
        END AS age_group,
        SUM(t.Sum_payment) AS group_quarter_revenue,
        COUNT(DISTINCT t.Id_check) AS group_quarter_transactions
    FROM transactions t
    LEFT JOIN customers c ON t.ID_client = c.Id_client
    WHERE t.date_new >= '2015-06-01' AND t.date_new < '2016-06-01'
    GROUP BY quarter_period, age_group
),
quarterly_totals AS (
    -- общие итоги каждого квартала
    SELECT 
        quarter_period,
        SUM(group_quarter_revenue) AS total_quarter_revenue,
        SUM(group_quarter_transactions) AS total_quarter_transactions
    FROM quarterly_raw
    GROUP BY quarter_period
)
-- поквартальная динамика, средние значения и доли
SELECT 
    r.quarter_period AS `Квартал`,
    r.age_group AS `Возрастная группа`,
    ROUND(r.group_quarter_revenue, 2) AS `Сумма за квартал`,
    r.group_quarter_transactions AS `Кол-во операций за квартал`,
    
    -- доля группы в общей выручке этого квартала
    ROUND((r.group_quarter_revenue / t.total_quarter_revenue) * 100, 2) AS `Доля в выручке квартала, %`,
    
    -- доля группы в общем количестве операций этого квартала
    ROUND((r.group_quarter_transactions / t.total_quarter_transactions) * 100, 2) AS `Доля в операциях квартала, %`
FROM 
    quarterly_raw r
JOIN 
    quarterly_totals t ON r.quarter_period = t.quarter_period
ORDER BY 
    r.quarter_period, r.age_group;