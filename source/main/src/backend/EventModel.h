#ifndef EVENTMODEL_H
#define EVENTMODEL_H

#include "DatabaseManager.h"
#include <QAbstractListModel>


class EventModel : public QAbstractListModel {
  Q_OBJECT

public:
  enum EventRoles {
    IdRole = Qt::UserRole + 1,
    NameRole,
    LocationRole,
    EventDateRole,
    UpdatedAtRole,
    CaptureModeRole,
    DigitalPropsRole,
    BeautyFilterRole,
    WatermarkRole,
    PostProcessingRole,
    ThumbnailPathRole,
    SelectedLayoutRole,
    CountdownDurationRole,  // Legacy, use FirstShotCountdownRole instead
    FirstShotCountdownRole,
    NextShotCountdownRole,
    ShotIntervalRole,
    AutoCutRole
  };

  explicit EventModel(DatabaseManager *dbManager, QObject *parent = nullptr);

  int rowCount(const QModelIndex &parent = QModelIndex()) const override;
  QVariant data(const QModelIndex &index,
                int role = Qt::DisplayRole) const override;
  QHash<int, QByteArray> roleNames() const override;

  Q_INVOKABLE void refresh();
  Q_INVOKABLE void searchEvents(const QString &query);
  Q_INVOKABLE int getEventId(int index) const;
  Q_INVOKABLE QVariantMap getEventData(int index) const;

signals:
  void eventsChanged();

private:
  DatabaseManager *m_dbManager;
  QList<Event> m_events;
};

#endif // EVENTMODEL_H
