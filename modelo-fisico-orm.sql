IF OBJECT_ID(N'[__EFMigrationsHistory]') IS NULL
BEGIN
    CREATE TABLE [__EFMigrationsHistory] (
        [MigrationId] nvarchar(150) NOT NULL,
        [ProductVersion] nvarchar(32) NOT NULL,
        CONSTRAINT [PK___EFMigrationsHistory] PRIMARY KEY ([MigrationId])
    );
END;
GO

BEGIN TRANSACTION;
CREATE TABLE [Trails] (
    [Id] uniqueidentifier NOT NULL,
    [Name] nvarchar(256) NOT NULL,
    [Description] nvarchar(max) NOT NULL,
    [CreatedAt] datetime2 NOT NULL,
    CONSTRAINT [PK_Trails] PRIMARY KEY ([Id])
);

CREATE TABLE [Users] (
    [Id] uniqueidentifier NOT NULL,
    [Name] nvarchar(256) NOT NULL,
    [Email] nvarchar(256) NOT NULL,
    [PasswordHash] nvarchar(max) NOT NULL,
    [Role] nvarchar(max) NOT NULL,
    [CreatedAt] datetime2 NOT NULL,
    CONSTRAINT [PK_Users] PRIMARY KEY ([Id])
);

CREATE TABLE [Challenges] (
    [Id] uniqueidentifier NOT NULL,
    [TrailId] uniqueidentifier NOT NULL,
    [Title] nvarchar(256) NOT NULL,
    [Description] nvarchar(max) NOT NULL,
    [Order] int NOT NULL,
    [CreatedAt] datetime2 NOT NULL,
    CONSTRAINT [PK_Challenges] PRIMARY KEY ([Id]),
    CONSTRAINT [FK_Challenges_Trails_TrailId] FOREIGN KEY ([TrailId]) REFERENCES [Trails] ([Id]) ON DELETE CASCADE
);

CREATE TABLE [Submissions] (
    [Id] uniqueidentifier NOT NULL,
    [StudentId] uniqueidentifier NOT NULL,
    [ChallengeId] uniqueidentifier NOT NULL,
    [DeliveryUrl] nvarchar(max) NOT NULL,
    [SubmittedAt] datetime2 NOT NULL,
    [Status] nvarchar(max) NOT NULL,
    [ReviewerId] uniqueidentifier NULL,
    [Score] int NULL,
    [Feedback] nvarchar(max) NULL,
    [ReviewedAt] datetime2 NULL,
    CONSTRAINT [PK_Submissions] PRIMARY KEY ([Id]),
    CONSTRAINT [FK_Submissions_Challenges_ChallengeId] FOREIGN KEY ([ChallengeId]) REFERENCES [Challenges] ([Id]) ON DELETE CASCADE,
    CONSTRAINT [FK_Submissions_Users_ReviewerId] FOREIGN KEY ([ReviewerId]) REFERENCES [Users] ([Id]) ON DELETE NO ACTION,
    CONSTRAINT [FK_Submissions_Users_StudentId] FOREIGN KEY ([StudentId]) REFERENCES [Users] ([Id]) ON DELETE NO ACTION
);

CREATE INDEX [IX_Challenges_TrailId] ON [Challenges] ([TrailId]);

CREATE INDEX [IX_Submissions_ChallengeId] ON [Submissions] ([ChallengeId]);

CREATE INDEX [IX_Submissions_ReviewerId] ON [Submissions] ([ReviewerId]);

CREATE INDEX [IX_Submissions_StudentId] ON [Submissions] ([StudentId]);

CREATE UNIQUE INDEX [IX_Users_Email] ON [Users] ([Email]);

INSERT INTO [__EFMigrationsHistory] ([MigrationId], [ProductVersion])
VALUES (N'20260410041722_InitialCreate', N'10.0.5');

COMMIT;
GO

BEGIN TRANSACTION;
DECLARE @var nvarchar(max);
SELECT @var = QUOTENAME([d].[name])
FROM [sys].[default_constraints] [d]
INNER JOIN [sys].[columns] [c] ON [d].[parent_column_id] = [c].[column_id] AND [d].[parent_object_id] = [c].[object_id]
WHERE ([d].[parent_object_id] = OBJECT_ID(N'[Submissions]') AND [c].[name] = N'Feedback');
IF @var IS NOT NULL EXEC(N'ALTER TABLE [Submissions] DROP CONSTRAINT ' + @var + ';');
ALTER TABLE [Submissions] ALTER COLUMN [Feedback] nvarchar(4000) NULL;

DECLARE @var1 nvarchar(max);
SELECT @var1 = QUOTENAME([d].[name])
FROM [sys].[default_constraints] [d]
INNER JOIN [sys].[columns] [c] ON [d].[parent_column_id] = [c].[column_id] AND [d].[parent_object_id] = [c].[object_id]
WHERE ([d].[parent_object_id] = OBJECT_ID(N'[Submissions]') AND [c].[name] = N'DeliveryUrl');
IF @var1 IS NOT NULL EXEC(N'ALTER TABLE [Submissions] DROP CONSTRAINT ' + @var1 + ';');
ALTER TABLE [Submissions] ALTER COLUMN [DeliveryUrl] nvarchar(2048) NOT NULL;

CREATE TABLE [RefreshTokens] (
    [Id] uniqueidentifier NOT NULL,
    [UserId] uniqueidentifier NOT NULL,
    [TokenHash] nvarchar(128) NOT NULL,
    [ExpiresAt] datetime2 NOT NULL,
    [CreatedAt] datetime2 NOT NULL,
    [RevokedAt] datetime2 NULL,
    [ReplacedByTokenHash] nvarchar(128) NULL,
    CONSTRAINT [PK_RefreshTokens] PRIMARY KEY ([Id]),
    CONSTRAINT [FK_RefreshTokens_Users_UserId] FOREIGN KEY ([UserId]) REFERENCES [Users] ([Id]) ON DELETE CASCADE
);

CREATE TABLE [TrailEnrollments] (
    [Id] uniqueidentifier NOT NULL,
    [UserId] uniqueidentifier NOT NULL,
    [TrailId] uniqueidentifier NOT NULL,
    [EnrolledAt] datetime2 NOT NULL,
    [CompletedAt] datetime2 NULL,
    CONSTRAINT [PK_TrailEnrollments] PRIMARY KEY ([Id]),
    CONSTRAINT [FK_TrailEnrollments_Trails_TrailId] FOREIGN KEY ([TrailId]) REFERENCES [Trails] ([Id]) ON DELETE CASCADE,
    CONSTRAINT [FK_TrailEnrollments_Users_UserId] FOREIGN KEY ([UserId]) REFERENCES [Users] ([Id]) ON DELETE CASCADE
);

CREATE TABLE [UserActivities] (
    [Id] uniqueidentifier NOT NULL,
    [UserId] uniqueidentifier NOT NULL,
    [ActivityType] nvarchar(64) NOT NULL,
    [TargetType] nvarchar(64) NULL,
    [TargetId] nvarchar(128) NULL,
    [Minutes] int NOT NULL,
    [OccurredAt] datetime2 NOT NULL,
    [CreatedAt] datetime2 NOT NULL,
    CONSTRAINT [PK_UserActivities] PRIMARY KEY ([Id]),
    CONSTRAINT [FK_UserActivities_Users_UserId] FOREIGN KEY ([UserId]) REFERENCES [Users] ([Id]) ON DELETE CASCADE
);

CREATE TABLE [UserSettings] (
    [Id] uniqueidentifier NOT NULL,
    [UserId] uniqueidentifier NOT NULL,
    [TwoFactorEnabled] bit NOT NULL,
    [PublicProfile] bit NOT NULL,
    [EmailNotifications] bit NOT NULL,
    [StudyReminder] bit NOT NULL,
    [AiSuggestions] bit NOT NULL,
    [WeeklyReport] bit NOT NULL,
    [Language] nvarchar(10) NOT NULL,
    [DailyStudyGoal] nvarchar(10) NOT NULL,
    [Autoplay] bit NOT NULL,
    [Subtitles] bit NOT NULL,
    [UpdatedAt] datetime2 NOT NULL,
    CONSTRAINT [PK_UserSettings] PRIMARY KEY ([Id]),
    CONSTRAINT [FK_UserSettings_Users_UserId] FOREIGN KEY ([UserId]) REFERENCES [Users] ([Id]) ON DELETE CASCADE
);

CREATE UNIQUE INDEX [IX_RefreshTokens_TokenHash] ON [RefreshTokens] ([TokenHash]);

CREATE INDEX [IX_RefreshTokens_UserId] ON [RefreshTokens] ([UserId]);

CREATE INDEX [IX_TrailEnrollments_TrailId] ON [TrailEnrollments] ([TrailId]);

CREATE UNIQUE INDEX [IX_TrailEnrollments_UserId_TrailId] ON [TrailEnrollments] ([UserId], [TrailId]);

CREATE INDEX [IX_UserActivities_UserId_OccurredAt] ON [UserActivities] ([UserId], [OccurredAt]);

CREATE UNIQUE INDEX [IX_UserSettings_UserId] ON [UserSettings] ([UserId]);

INSERT INTO [__EFMigrationsHistory] ([MigrationId], [ProductVersion])
VALUES (N'20260602183058_SharedBaseFoundation', N'10.0.5');

COMMIT;
GO

BEGIN TRANSACTION;
DECLARE @var2 nvarchar(max);
SELECT @var2 = QUOTENAME([d].[name])
FROM [sys].[default_constraints] [d]
INNER JOIN [sys].[columns] [c] ON [d].[parent_column_id] = [c].[column_id] AND [d].[parent_object_id] = [c].[object_id]
WHERE ([d].[parent_object_id] = OBJECT_ID(N'[Submissions]') AND [c].[name] = N'Feedback');
IF @var2 IS NOT NULL EXEC(N'ALTER TABLE [Submissions] DROP CONSTRAINT ' + @var2 + ';');
ALTER TABLE [Submissions] DROP COLUMN [Feedback];

DECLARE @var3 nvarchar(max);
SELECT @var3 = QUOTENAME([d].[name])
FROM [sys].[default_constraints] [d]
INNER JOIN [sys].[columns] [c] ON [d].[parent_column_id] = [c].[column_id] AND [d].[parent_object_id] = [c].[object_id]
WHERE ([d].[parent_object_id] = OBJECT_ID(N'[Submissions]') AND [c].[name] = N'Score');
IF @var3 IS NOT NULL EXEC(N'ALTER TABLE [Submissions] DROP CONSTRAINT ' + @var3 + ';');
ALTER TABLE [Submissions] DROP COLUMN [Score];

EXEC sp_rename N'[Submissions].[DeliveryUrl]', N'GitHubUrl', 'COLUMN';

ALTER TABLE [Submissions] ADD [MentorComment] nvarchar(500) NULL;

ALTER TABLE [Challenges] ADD [YouTubeUrl] nvarchar(2048) NULL;

UPDATE Submissions SET Status = 'Approved' WHERE Status = 'Reviewed'

INSERT INTO [__EFMigrationsHistory] ([MigrationId], [ProductVersion])
VALUES (N'20260604040451_LeanSubmissionModel', N'10.0.5');

COMMIT;
GO

BEGIN TRANSACTION;
ALTER TABLE [Challenges] ADD [AiSearchTerms] nvarchar(max) NULL;

CREATE TABLE [OnboardingProfiles] (
    [Id] uniqueidentifier NOT NULL,
    [UserId] uniqueidentifier NOT NULL,
    [TargetRole] nvarchar(256) NOT NULL,
    [TechnicalDepth] nvarchar(32) NOT NULL,
    [WeeklyHours] nvarchar(16) NOT NULL,
    [LearningStyle] nvarchar(32) NOT NULL,
    [ProjectGoal] nvarchar(1000) NOT NULL,
    [CreatedAt] datetime2 NOT NULL,
    [UpdatedAt] datetime2 NOT NULL,
    CONSTRAINT [PK_OnboardingProfiles] PRIMARY KEY ([Id]),
    CONSTRAINT [FK_OnboardingProfiles_Users_UserId] FOREIGN KEY ([UserId]) REFERENCES [Users] ([Id]) ON DELETE CASCADE
);

CREATE UNIQUE INDEX [IX_OnboardingProfiles_UserId] ON [OnboardingProfiles] ([UserId]);

INSERT INTO [__EFMigrationsHistory] ([MigrationId], [ProductVersion])
VALUES (N'20260604073349_AddAiFeatures', N'10.0.5');

COMMIT;
GO
