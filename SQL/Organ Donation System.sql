-- =============================================================================
-- ORGAN DONATION SYSTEM
-- Database Management Systems Project
-- Thapar Institute of Engineering and Technology, Patiala
-- 
-- Students: Sach Kanwar Singh Nijjar (1024030198)
--           Sehajpreet Singh Saran   (1024030214)
-- Academic Year: 2025-2026
-- Database: MySQL 8.0+
-- =============================================================================

-- Use/Create the working database
CREATE DATABASE IF NOT EXISTS organ_donation_db;
USE organ_donation_db;

-- =============================================================================
-- RERUN SAFETY: DROP EXISTING VIEWS, ROUTINES, AND TRIGGERS
-- =============================================================================
DROP VIEW IF EXISTS vw_Transplant_Log;
DROP VIEW IF EXISTS vw_Organ_Summary;

DROP PROCEDURE IF EXISTS sp_RegisterTransplant;
DROP PROCEDURE IF EXISTS sp_GetWaitlist;
DROP PROCEDURE IF EXISTS sp_ExpireOldOrgans;

DROP FUNCTION IF EXISTS fn_IsCompatible;
DROP FUNCTION IF EXISTS fn_DoctorSuccessCount;

DROP TRIGGER IF EXISTS trg_CheckOrganAvailability;
DROP TRIGGER IF EXISTS trg_UpdateOrganStatus;
DROP TRIGGER IF EXISTS trg_DonorDeleteAudit;

-- =============================================================================
-- SECTION 1: DDL – TABLE CREATION
-- =============================================================================

-- Drop tables in reverse dependency order if they exist (for clean re-run)
DROP TABLE IF EXISTS Donor_Audit_Log;
DROP TABLE IF EXISTS Patient_Phone;
DROP TABLE IF EXISTS Donor_Phone;
DROP TABLE IF EXISTS `Transaction`;
DROP TABLE IF EXISTS Organ_Available;
DROP TABLE IF EXISTS Doctor;
DROP TABLE IF EXISTS Organization;
DROP TABLE IF EXISTS Patient;
DROP TABLE IF EXISTS Donor;
DROP TABLE IF EXISTS `User`;

-- 1.1 User Table
CREATE TABLE `User` (
    User_ID   INT           AUTO_INCREMENT PRIMARY KEY,
    Name      VARCHAR(100)  NOT NULL,
    Email     VARCHAR(150)  NOT NULL UNIQUE,
    Password  VARCHAR(255)  NOT NULL,
    Role      ENUM('donor','patient','doctor','admin') NOT NULL
);

-- 1.2 Donor Table
CREATE TABLE Donor (
    Donor_ID        INT   AUTO_INCREMENT PRIMARY KEY,
    User_ID         INT   NOT NULL,
    Blood_Group     VARCHAR(5)  NOT NULL,
    DOB             DATE        NOT NULL,
    Medical_History TEXT,
    FOREIGN KEY (User_ID) REFERENCES `User`(User_ID) ON DELETE CASCADE
);

-- 1.3 Patient Table
CREATE TABLE Patient (
    Patient_ID     INT           AUTO_INCREMENT PRIMARY KEY,
    User_ID        INT           NOT NULL,
    Blood_Group    VARCHAR(5)    NOT NULL,
    Disease        VARCHAR(200)  NOT NULL,
    Priority_Level INT           NOT NULL CHECK (Priority_Level BETWEEN 1 AND 5),
    Waitlist_Date  DATE          NOT NULL,
    FOREIGN KEY (User_ID) REFERENCES `User`(User_ID) ON DELETE CASCADE
);

-- 1.4 Organization Table
CREATE TABLE Organization (
    Org_ID   INT           AUTO_INCREMENT PRIMARY KEY,
    Name     VARCHAR(150)  NOT NULL,
    Type     VARCHAR(50)   NOT NULL,
    Address  VARCHAR(255),
    Contact  VARCHAR(15)
);

-- 1.5 Doctor Table
CREATE TABLE Doctor (
    Doctor_ID      INT           AUTO_INCREMENT PRIMARY KEY,
    User_ID        INT           NOT NULL,
    Specialization VARCHAR(100)  NOT NULL,
    License_No     VARCHAR(50)   NOT NULL UNIQUE,
    Org_ID         INT,
    FOREIGN KEY (User_ID) REFERENCES `User`(User_ID) ON DELETE CASCADE,
    FOREIGN KEY (Org_ID)  REFERENCES Organization(Org_ID)
);

-- 1.6 Organ_Available Table
CREATE TABLE Organ_Available (
    Organ_ID     INT          AUTO_INCREMENT PRIMARY KEY,
    Donor_ID     INT          NOT NULL,
    Organ_Type   VARCHAR(50)  NOT NULL,
    Status       ENUM('available','allocated','transplanted','expired') NOT NULL DEFAULT 'available',
    Harvest_Date DATE         NOT NULL,
    FOREIGN KEY (Donor_ID) REFERENCES Donor(Donor_ID)
);

-- 1.7 Transaction Table
CREATE TABLE `Transaction` (
    Transaction_ID  INT   AUTO_INCREMENT PRIMARY KEY,
    Organ_ID        INT   NOT NULL,
    Patient_ID      INT   NOT NULL,
    Doctor_ID       INT   NOT NULL,
    Trans_Date      DATE  NOT NULL,
    Outcome         ENUM('success','failure','pending') NOT NULL DEFAULT 'pending',
    FOREIGN KEY (Organ_ID)   REFERENCES Organ_Available(Organ_ID),
    FOREIGN KEY (Patient_ID) REFERENCES Patient(Patient_ID),
    FOREIGN KEY (Doctor_ID)  REFERENCES Doctor(Doctor_ID)
);

-- 1.8 Phone Number Tables (1NF compliance)
CREATE TABLE Donor_Phone (
    Donor_ID INT         NOT NULL,
    Phone    VARCHAR(15) NOT NULL,
    PRIMARY KEY (Donor_ID, Phone),
    FOREIGN KEY (Donor_ID) REFERENCES Donor(Donor_ID) ON DELETE CASCADE
);

CREATE TABLE Patient_Phone (
    Patient_ID INT         NOT NULL,
    Phone      VARCHAR(15) NOT NULL,
    PRIMARY KEY (Patient_ID, Phone),
    FOREIGN KEY (Patient_ID) REFERENCES Patient(Patient_ID) ON DELETE CASCADE
);

-- 1.9 Audit Log Table (used by trigger)
CREATE TABLE Donor_Audit_Log (
    Log_ID     INT      AUTO_INCREMENT PRIMARY KEY,
    Donor_ID   INT,
    Deleted_At DATETIME DEFAULT NOW()
);


-- =============================================================================
-- SECTION 2: DML – SAMPLE DATA
-- =============================================================================

-- Insert Users
INSERT INTO `User` (Name, Email, Password, Role) VALUES
  ('Arjun Sharma',      'arjun@mail.com',        'hashed_pw1',  'donor'),
  ('Priya Mehta',       'priya@mail.com',         'hashed_pw2',  'patient'),
  ('Dr. Ravi Singh',    'ravi@hospital.com',      'hashed_pw3',  'doctor'),
  ('Kavya Nair',        'kavya@mail.com',          'hashed_pw4',  'donor'),
  ('Rahul Verma',       'rahul@mail.com',          'hashed_pw5',  'patient'),
  ('Dr. Sunita Bose',   'sunita@apollo.com',       'hashed_pw6',  'doctor'),
  ('Manpreet Kaur',     'manpreet@mail.com',       'hashed_pw7',  'patient'),
  ('Deepak Joshi',      'deepak@mail.com',         'hashed_pw8',  'donor');

-- Insert Donors
INSERT INTO Donor (User_ID, Blood_Group, DOB, Medical_History) VALUES
  (1, 'O+',  '1985-04-12', 'No prior conditions'),
  (4, 'A-',  '1990-08-22', 'Mild hypertension'),
  (8, 'B+',  '1978-11-05', NULL);

-- Insert Patients
INSERT INTO Patient (User_ID, Blood_Group, Disease, Priority_Level, Waitlist_Date) VALUES
  (2, 'O+',  'End-stage Renal Disease',   1, '2024-01-10'),
  (5, 'A-',  'Hepatic Failure',           2, '2024-03-15'),
  (7, 'B+',  'Dilated Cardiomyopathy',    1, '2024-05-01');

-- Insert Organizations
INSERT INTO Organization (Name, Type, Address, Contact) VALUES
  ('AIIMS Delhi',      'Hospital',   'Ansari Nagar, New Delhi',         '011-26588500'),
  ('Apollo Hospitals', 'Hospital',   'Greams Road, Chennai',            '044-28293333'),
  ('NOTTO',            'Regulatory', 'R. K. Puram, New Delhi',          '011-26162785');

-- Insert Doctors
INSERT INTO Doctor (User_ID, Specialization, License_No, Org_ID) VALUES
  (3, 'Transplant Surgery',      'LIC-2023-881', 1),
  (6, 'Hepatobiliary Surgery',   'LIC-2021-445', 2);

-- Insert Organs
INSERT INTO Organ_Available (Donor_ID, Organ_Type, Status, Harvest_Date) VALUES
  (1, 'Kidney',  'available',    '2024-06-01'),
  (2, 'Liver',   'available',    '2024-06-05'),
  (3, 'Heart',   'available',    '2024-06-08'),
  (1, 'Cornea',  'transplanted', '2024-02-10'),
  (2, 'Kidney',  'expired',      '2024-01-20');

-- Insert Transactions
INSERT INTO `Transaction` (Organ_ID, Patient_ID, Doctor_ID, Trans_Date, Outcome) VALUES
  (4, 1, 1, '2024-02-11', 'success');

-- Insert Phone Numbers
INSERT INTO Donor_Phone   (Donor_ID, Phone) VALUES (1, '9876543210'), (2, '8765432109');
INSERT INTO Patient_Phone (Patient_ID, Phone) VALUES (1, '7654321098'), (2, '6543210987');


-- =============================================================================
-- SECTION 3: COMPLEX SQL QUERIES
-- =============================================================================

-- Query 1: All available organs with donor details
SELECT oa.Organ_ID, oa.Organ_Type, oa.Harvest_Date,
       u.Name AS Donor_Name, d.Blood_Group
FROM   Organ_Available oa
JOIN   Donor d  ON oa.Donor_ID = d.Donor_ID
JOIN  `User`  u  ON d.User_ID   = u.User_ID
WHERE  oa.Status = 'available'
ORDER  BY oa.Harvest_Date ASC;

-- Query 2: Patients on waitlist ordered by priority and blood group
SELECT p.Patient_ID, u.Name, p.Blood_Group, p.Disease,
       p.Priority_Level, p.Waitlist_Date
FROM   Patient p
JOIN  `User` u ON p.User_ID = u.User_ID
ORDER  BY p.Priority_Level ASC, p.Waitlist_Date ASC;

-- Query 3: Total transplants per doctor with success count
SELECT u.Name AS Doctor_Name, o.Name AS Organization,
       COUNT(t.Transaction_ID) AS Total_Surgeries,
       SUM(CASE WHEN t.Outcome = 'success' THEN 1 ELSE 0 END) AS Successful
FROM   `Transaction` t
JOIN   Doctor        d   ON t.Doctor_ID = d.Doctor_ID
JOIN  `User`         u   ON d.User_ID   = u.User_ID
LEFT JOIN Organization o ON d.Org_ID    = o.Org_ID
GROUP  BY t.Doctor_ID
HAVING Total_Surgeries > 0
ORDER  BY Successful DESC;

-- Query 4: Patients who received a blood-group-compatible organ
SELECT u.Name AS Patient_Name, p.Blood_Group,
       oa.Organ_Type, t.Trans_Date, t.Outcome
FROM  `Transaction`  t
JOIN   Patient        p  ON t.Patient_ID = p.Patient_ID
JOIN  `User`          u  ON p.User_ID    = u.User_ID
JOIN   Organ_Available oa ON t.Organ_ID  = oa.Organ_ID
JOIN   Donor           d  ON oa.Donor_ID = d.Donor_ID
WHERE  p.Blood_Group = d.Blood_Group;

-- Query 5: Organs donated per donor (GROUP BY + HAVING)
SELECT u.Name AS Donor_Name, d.Blood_Group,
       COUNT(oa.Organ_ID) AS Organs_Donated
FROM   Donor          d
JOIN  `User`          u  ON d.User_ID  = u.User_ID
LEFT JOIN Organ_Available oa ON oa.Donor_ID = d.Donor_ID
GROUP  BY d.Donor_ID
HAVING COUNT(oa.Organ_ID) > 0
ORDER  BY Organs_Donated DESC;

-- Query 6: Subquery – Patients whose blood group has at least one available organ
SELECT u.Name, p.Blood_Group, p.Disease
FROM   Patient p
JOIN  `User`   u ON p.User_ID = u.User_ID
WHERE  p.Blood_Group IN (
    SELECT DISTINCT d.Blood_Group
    FROM   Organ_Available oa
    JOIN   Donor d ON oa.Donor_ID = d.Donor_ID
    WHERE  oa.Status = 'available'
);


-- =============================================================================
-- SECTION 4: SQL VIEWS
-- =============================================================================

-- View 1: Organ availability summary by type
CREATE OR REPLACE VIEW vw_Organ_Summary AS
SELECT oa.Organ_Type,
       COUNT(*)                              AS Total,
       SUM(oa.Status = 'available')          AS Available,
       SUM(oa.Status = 'allocated')          AS Allocated,
       SUM(oa.Status = 'transplanted')       AS Transplanted,
       SUM(oa.Status = 'expired')            AS Expired
FROM   Organ_Available oa
GROUP  BY oa.Organ_Type;

-- View 2: Transplant audit log
CREATE OR REPLACE VIEW vw_Transplant_Log AS
SELECT t.Transaction_ID, t.Trans_Date, t.Outcome,
       ud.Name   AS Donor_Name,    oa.Organ_Type,
       up.Name   AS Patient_Name,   p.Blood_Group AS Patient_BG,
       udoc.Name AS Doctor_Name,    o.Name        AS Hospital
FROM  `Transaction`    t
JOIN   Organ_Available oa   ON t.Organ_ID   = oa.Organ_ID
JOIN   Donor           d    ON oa.Donor_ID  = d.Donor_ID
JOIN  `User`           ud   ON d.User_ID    = ud.User_ID
JOIN   Patient         p    ON t.Patient_ID = p.Patient_ID
JOIN  `User`           up   ON p.User_ID    = up.User_ID
JOIN   Doctor          doc  ON t.Doctor_ID  = doc.Doctor_ID
JOIN  `User`           udoc ON doc.User_ID  = udoc.User_ID
LEFT JOIN Organization o    ON doc.Org_ID   = o.Org_ID;

-- Query views
SELECT * FROM vw_Organ_Summary;
SELECT * FROM vw_Transplant_Log;


-- =============================================================================
-- SECTION 5: PL/SQL – STORED PROCEDURES
-- =============================================================================

-- 5.1 Procedure: Register a Transplant
DELIMITER $$

CREATE PROCEDURE sp_RegisterTransplant (
    IN  p_Organ_ID   INT,
    IN  p_Patient_ID INT,
    IN  p_Doctor_ID  INT,
    IN  p_Date       DATE,
    OUT p_Result     VARCHAR(100)
)
BEGIN
    DECLARE v_Status VARCHAR(20);

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET p_Result = 'ERROR: Transaction rolled back due to an exception.';
    END;

    START TRANSACTION;

    -- Lock and read organ status
    SELECT Status INTO v_Status
    FROM   Organ_Available
    WHERE  Organ_ID = p_Organ_ID
    FOR UPDATE;

    IF v_Status != 'available' THEN
        SET p_Result = 'ERROR: Organ is not available for transplant.';
        ROLLBACK;
    ELSE
        -- Insert transplant record
        INSERT INTO `Transaction` (Organ_ID, Patient_ID, Doctor_ID, Trans_Date, Outcome)
        VALUES (p_Organ_ID, p_Patient_ID, p_Doctor_ID, p_Date, 'pending');

        -- Mark organ as allocated
        UPDATE Organ_Available
        SET    Status = 'allocated'
        WHERE  Organ_ID = p_Organ_ID;

        COMMIT;
        SET p_Result = 'SUCCESS: Transplant registered successfully.';
    END IF;
END$$

DELIMITER ;

-- Test Procedure 1
CALL sp_RegisterTransplant(1, 1, 1, CURDATE(), @result);
SELECT @result;

-- 5.2 Procedure: Get Waitlisted Patients by Blood Group
DELIMITER $$

CREATE PROCEDURE sp_GetWaitlist (IN p_BloodGroup VARCHAR(5))
BEGIN
    SELECT p.Patient_ID, u.Name, p.Disease,
           p.Priority_Level, p.Waitlist_Date, p.Blood_Group
    FROM   Patient p
    JOIN  `User`   u ON p.User_ID = u.User_ID
    WHERE  p.Blood_Group = p_BloodGroup
    ORDER  BY p.Priority_Level ASC, p.Waitlist_Date ASC;
END$$

DELIMITER ;

-- Test Procedure 2
CALL sp_GetWaitlist('O+');

-- 5.3 Procedure: Expire old organs (uses cursor – see Section 7)
-- (defined in the Cursors section below)


-- =============================================================================
-- SECTION 6: PL/SQL – FUNCTIONS
-- =============================================================================

-- 6.1 Function: Check Blood Group Compatibility (ABO rules)
DELIMITER $$

CREATE FUNCTION fn_IsCompatible (
    p_DonorBG   VARCHAR(5),
    p_PatientBG VARCHAR(5)
)
RETURNS INT
DETERMINISTIC
BEGIN
    -- Universal donor O- compatible with all
    IF p_DonorBG = 'O-'  THEN RETURN 1; END IF;

    -- Exact match always compatible
    IF p_DonorBG = p_PatientBG THEN RETURN 1; END IF;

    -- O+ compatible with all positive groups
    IF p_DonorBG = 'O+'  AND p_PatientBG IN ('A+','B+','AB+','O+')      THEN RETURN 1; END IF;

    -- A- compatible with A and AB groups
    IF p_DonorBG = 'A-'  AND p_PatientBG IN ('A+','A-','AB+','AB-')     THEN RETURN 1; END IF;

    -- A+ compatible with A+ and AB+
    IF p_DonorBG = 'A+'  AND p_PatientBG IN ('A+','AB+')                THEN RETURN 1; END IF;

    -- B- compatible with B and AB groups
    IF p_DonorBG = 'B-'  AND p_PatientBG IN ('B+','B-','AB+','AB-')     THEN RETURN 1; END IF;

    -- B+ compatible with B+ and AB+
    IF p_DonorBG = 'B+'  AND p_PatientBG IN ('B+','AB+')                THEN RETURN 1; END IF;

    -- AB- compatible with AB groups
    IF p_DonorBG = 'AB-' AND p_PatientBG IN ('AB+','AB-')               THEN RETURN 1; END IF;

    RETURN 0;
END$$

DELIMITER ;

-- Test Function 1: Check compatibility between O+ donor and A+ patient
SELECT fn_IsCompatible('O+', 'A+') AS Compatible;  -- Expected: 1
SELECT fn_IsCompatible('A+', 'B+') AS Compatible;  -- Expected: 0

-- 6.2 Function: Count Successful Transplants by Doctor
DELIMITER $$

CREATE FUNCTION fn_DoctorSuccessCount (p_Doctor_ID INT)
RETURNS INT
READS SQL DATA
BEGIN
    DECLARE v_Count INT;

    SELECT COUNT(*) INTO v_Count
    FROM  `Transaction`
    WHERE  Doctor_ID = p_Doctor_ID
    AND    Outcome   = 'success';

    RETURN v_Count;
END$$

DELIMITER ;

-- Test Function 2
SELECT u.Name AS Doctor_Name, fn_DoctorSuccessCount(d.Doctor_ID) AS Successful_Surgeries
FROM   Doctor d
JOIN  `User`  u ON d.User_ID = u.User_ID;


-- =============================================================================
-- SECTION 7: PL/SQL – CURSORS
-- =============================================================================

-- Cursor inside stored procedure: Batch-expire organs older than 1 day
DELIMITER $$

CREATE PROCEDURE sp_ExpireOldOrgans()
BEGIN
    DECLARE done    INT DEFAULT FALSE;
    DECLARE v_OID   INT;
    DECLARE v_Count INT DEFAULT 0;

    DECLARE cur_organs CURSOR FOR
        SELECT Organ_ID
        FROM   Organ_Available
        WHERE  Status       = 'available'
        AND    DATEDIFF(NOW(), Harvest_Date) > 1;

    DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = TRUE;

    OPEN cur_organs;

    read_loop: LOOP
        FETCH cur_organs INTO v_OID;
        IF done THEN LEAVE read_loop; END IF;

        UPDATE Organ_Available
        SET    Status = 'expired'
        WHERE  Organ_ID = v_OID;

        SET v_Count = v_Count + 1;
    END LOOP;

    CLOSE cur_organs;

    COMMIT;
    SELECT CONCAT(v_Count, ' organ(s) marked as expired.') AS Result;
END$$

DELIMITER ;

-- Test Cursor procedure
-- With the sample data and the earlier sp_RegisterTransplant call, this should expire
-- the remaining available old organ records and return the count.
CALL sp_ExpireOldOrgans();


-- =============================================================================
-- SECTION 8: PL/SQL – TRIGGERS
-- =============================================================================

-- Trigger 1: BEFORE INSERT on Transaction – Prevent double-allocation
DELIMITER $$

CREATE TRIGGER trg_CheckOrganAvailability
BEFORE INSERT ON `Transaction`
FOR EACH ROW
BEGIN
    DECLARE v_Status VARCHAR(20);

    SELECT Status INTO v_Status
    FROM   Organ_Available
    WHERE  Organ_ID = NEW.Organ_ID;

    IF v_Status != 'available' THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'ERROR: Organ is not available for transplant.';
    END IF;
END$$

DELIMITER ;

-- Trigger 2: AFTER UPDATE on Transaction – Auto-update organ status to transplanted
DELIMITER $$

CREATE TRIGGER trg_UpdateOrganStatus
AFTER UPDATE ON `Transaction`
FOR EACH ROW
BEGIN
    IF NEW.Outcome = 'success' AND OLD.Outcome != 'success' THEN
        UPDATE Organ_Available
        SET    Status = 'transplanted'
        WHERE  Organ_ID = NEW.Organ_ID;
    END IF;
END$$

DELIMITER ;

-- Trigger 3: BEFORE DELETE on Donor – Audit log
DELIMITER $$

CREATE TRIGGER trg_DonorDeleteAudit
BEFORE DELETE ON Donor
FOR EACH ROW
BEGIN
    INSERT INTO Donor_Audit_Log (Donor_ID)
    VALUES (OLD.Donor_ID);
END$$

DELIMITER ;

-- Test Triggers:
-- Test Trigger 1 (should fail – organ already allocated)
-- INSERT INTO `Transaction` (Organ_ID, Patient_ID, Doctor_ID, Trans_Date, Outcome)
-- VALUES (4, 2, 1, CURDATE(), 'pending');  -- Organ 4 is 'transplanted' -> should raise error

-- Test Trigger 2: Update outcome to success -> should set organ to 'transplanted'
-- UPDATE `Transaction` SET Outcome = 'success' WHERE Transaction_ID = 2;
-- SELECT * FROM Organ_Available WHERE Organ_ID = 1;


-- =============================================================================
-- SECTION 9: TRANSACTION MANAGEMENT
-- =============================================================================

-- 9.1 COMMIT / ROLLBACK Example
START TRANSACTION;

    -- Step 1: Insert a new patient
    INSERT INTO `User` (Name, Email, Password, Role)
    VALUES ('Test Patient', 'test@mail.com', 'hashed_pw_test', 'patient');

    -- Step 2: Register patient details
    INSERT INTO Patient (User_ID, Blood_Group, Disease, Priority_Level, Waitlist_Date)
    VALUES (LAST_INSERT_ID(), 'AB+', 'Liver Cirrhosis', 2, CURDATE());

COMMIT;  -- Both inserts committed atomically

-- 9.2 SAVEPOINT Example
START TRANSACTION;

    INSERT INTO `User` (Name, Email, Password, Role)
    VALUES ('Savepoint User', 'savepoint@mail.com', 'hashed_pw_sp', 'patient');

    SAVEPOINT sp_after_user;

    INSERT INTO Patient (User_ID, Blood_Group, Disease, Priority_Level, Waitlist_Date)
    VALUES (LAST_INSERT_ID(), 'O-', 'Cardiac Failure', 1, CURDATE());

    SAVEPOINT sp_after_patient;

    -- If phone insert is invalid, roll back only the phone
    -- ROLLBACK TO SAVEPOINT sp_after_patient;

COMMIT;


-- =============================================================================
-- SECTION 10: VERIFICATION QUERIES (Sample Output)
-- =============================================================================

-- Show all users
SELECT * FROM `User`;

-- Show donors with blood groups
SELECT d.Donor_ID, u.Name, d.Blood_Group, d.DOB FROM Donor d JOIN `User` u ON d.User_ID = u.User_ID;

-- Show patients on waitlist
SELECT p.Patient_ID, u.Name, p.Blood_Group, p.Disease, p.Priority_Level
FROM Patient p JOIN `User` u ON p.User_ID = u.User_ID ORDER BY p.Priority_Level;

-- Show organ availability
SELECT * FROM Organ_Available;

-- Show transactions
SELECT * FROM `Transaction`;

-- Show transplant log view
SELECT * FROM vw_Transplant_Log;

-- Show organ summary view
SELECT * FROM vw_Organ_Summary;

-- Check audit log
SELECT * FROM Donor_Audit_Log;

-- =============================================================================
-- END OF IMPLEMENTATION
-- =============================================================================
